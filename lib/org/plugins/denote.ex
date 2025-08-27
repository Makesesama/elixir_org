defmodule Org.Plugins.Denote do
  @moduledoc """
  Plugin for Denote-specific features in org-mode.

  Supports:
  - Flexible Denote filename parsing (@@ID==SIGNATURE--TITLE__KEYWORDS.EXT)
  - Denote link parsing (denote:ID, query links, heading targets)
  - Dynamic blocks (backlinks, files, links)
  - Front matter mapping with filenames
  - Encrypted file support (.org.gpg)
  """

  use Org.Parser.Plugin

  defmodule DenoteLink do
    @moduledoc """
    Represents a Denote-style link.
    """
    defstruct [:id, :description, :type, :heading_id, :query]

    @type t :: %__MODULE__{
            id: String.t() | nil,
            description: String.t() | nil,
            type: :denote | :id | :query_contents | :query_filenames,
            heading_id: String.t() | nil,
            query: String.t() | nil
          }
  end

  defmodule DenoteBlock do
    @moduledoc """
    Dynamic block for Denote features like backlinks.
    """
    defstruct [:type, :params, :content]
  end

  defmodule FilenameComponents do
    @moduledoc """
    Parsed Denote filename components.
    """
    defstruct [:id, :signature, :title, :keywords, :extension]

    @type t :: %__MODULE__{
            id: String.t(),
            signature: String.t() | nil,
            title: String.t(),
            keywords: [String.t()],
            extension: String.t()
          }
  end

  @impl true
  def patterns do
    [
      "[[denote:",
      "[[id:",
      "#+BEGIN: denote-",
      # Denote filename pattern with flexible separators
      ~r/^\d{8}T\d{6}/,
      ~r/@@\d{8}T\d{6}/
    ]
  end

  @impl true
  # Higher priority for Denote-specific patterns
  def priority, do: 30

  @impl true
  def init(_opts) do
    # Initialize Denote index if needed
    {:ok, %{index: %{}}}
  end

  @impl true
  def parse(<<"[[denote:", rest::binary>>, _context) do
    parse_denote_link(rest, :denote)
  end

  def parse(<<"[[id:", rest::binary>>, _context) do
    parse_denote_link(rest, :id)
  end

  def parse(<<"#+BEGIN: denote-", rest::binary>>, context) do
    parse_denote_block(rest, context)
  end

  def parse(content, context) do
    # Check if it's a Denote filename
    if denote_filename?(content) do
      parse_denote_filename(content, context)
    else
      :skip
    end
  end

  @doc """
  Parse a Denote filename with flexible component ordering.
  Supports: @@ID==SIGNATURE--TITLE__KEYWORDS.EXT
  """
  def parse_filename(filename) do
    extract_filename_components(filename)
  end

  @doc """
  Extract Denote ID from a filename (legacy support).
  """
  def extract_denote_id(filename) do
    case parse_filename(filename) do
      {:ok, %{id: id}} -> {:ok, id}
      _ -> :error
    end
  end

  @doc """
  Generate a Denote-compliant filename.
  """
  def generate_filename(title, keywords \\ [], timestamp \\ DateTime.utc_now(), signature \\ nil) do
    id = format_denote_id(timestamp)
    title_part = slugify(title)
    keywords_part = if keywords == [], do: "", else: "__#{Enum.join(keywords, "_")}"
    signature_part = if signature, do: "==#{signature}", else: ""

    # Standard format: ID==SIGNATURE--TITLE__KEYWORDS.org
    # Without signature: ID--TITLE__KEYWORDS.org
    if signature do
      "@@#{id}#{signature_part}--#{title_part}#{keywords_part}.org"
    else
      "#{id}--#{title_part}#{keywords_part}.org"
    end
  end

  @doc """
  Map filename components to Org front matter.
  """
  def filename_to_frontmatter(%FilenameComponents{} = components) do
    %{
      identifier: components.id,
      title: unslugify(components.title),
      filetags: keywords_to_org_tags(components.keywords),
      date: parse_denote_timestamp(components.id)
    }
  end

  @doc """
  Convert Org front matter to filename components.
  """
  def frontmatter_to_filename(frontmatter) do
    %FilenameComponents{
      id: frontmatter[:identifier] || format_denote_id(DateTime.utc_now()),
      signature: frontmatter[:signature],
      title: slugify(frontmatter[:title] || ""),
      keywords: org_tags_to_keywords(frontmatter[:filetags]),
      extension: ".org"
    }
  end

  @doc """
  Find all backlinks to a given Denote ID.
  """
  def find_backlinks(workspace, denote_id) do
    workspace.file_entries
    |> Enum.flat_map(fn entry ->
      links = extract_denote_links(entry.document)

      links
      |> Enum.filter(fn link -> link.id == denote_id end)
      |> Enum.map(fn _link -> entry.filename end)
    end)
    |> Enum.uniq()
  end

  @doc """
  Search content across Denote notes.
  """
  def query_contents(workspace, regexp) do
    regex = Regex.compile!(regexp)

    workspace.file_entries
    |> Enum.filter(fn entry ->
      content = document_to_text(entry.document)
      Regex.match?(regex, content)
    end)
    |> Enum.map(& &1.filename)
  end

  @doc """
  Search filenames across Denote notes.
  """
  def query_filenames(workspace, regexp) do
    regex = Regex.compile!(regexp)

    workspace.file_entries
    |> Enum.filter(fn entry ->
      Regex.match?(regex, entry.filename)
    end)
    |> Enum.map(& &1.filename)
  end

  # Private functions

  defp parse_denote_link(content, type) when type in [:denote, :id] do
    cond do
      # Query links: denote:query-contents:REGEXP or denote:query-filenames:REGEXP
      String.starts_with?(content, "query-contents:") ->
        parse_query_link(content, :query_contents)

      String.starts_with?(content, "query-filenames:") ->
        parse_query_link(content, :query_filenames)

      # Regular link with possible heading target
      true ->
        parse_regular_denote_link(content, type)
    end
  end

  defp parse_query_link(content, query_type) do
    prefix_length =
      case query_type do
        # "query-contents:"
        :query_contents -> 15
        # "query-filenames:"
        :query_filenames -> 16
      end

    rest = String.slice(content, prefix_length..-1)

    case extract_link_parts(rest) do
      {:ok, query, description} ->
        link = %DenoteLink{
          type: query_type,
          query: query,
          description: description || query
        }

        {:ok, link}

      :error ->
        {:error, :invalid_denote_query}
    end
  end

  defp parse_regular_denote_link(content, type) do
    case extract_link_with_heading(content) do
      {:ok, id, heading_id, description} ->
        link = %DenoteLink{
          id: id,
          heading_id: heading_id,
          description: description,
          type: type
        }

        {:ok, link}

      :error ->
        {:error, :invalid_denote_link}
    end
  end

  defp extract_link_with_heading(content) do
    case String.split(content, "]]", parts: 2) do
      [link_content, _rest] ->
        case String.split(link_content, "][", parts: 2) do
          [target, desc] ->
            {id, heading} = parse_target_with_heading(target)
            {:ok, id, heading, desc}

          [target] ->
            {id, heading} = parse_target_with_heading(target)
            {:ok, id, heading, nil}
        end

      _ ->
        :error
    end
  end

  defp parse_target_with_heading(target) do
    case String.split(target, "::#", parts: 2) do
      [id, heading] -> {id, heading}
      [id] -> {id, nil}
    end
  end

  defp extract_link_parts(content) do
    case String.split(content, "]]", parts: 2) do
      [link_content, _rest] ->
        case String.split(link_content, "][", parts: 2) do
          [id, desc] -> {:ok, id, desc}
          [id] -> {:ok, id, nil}
        end

      _ ->
        :error
    end
  end

  defp parse_denote_block(content, _context) do
    {block_type, params, _remaining} = parse_block_header(content)

    case block_type do
      "links" ->
        {:ok, create_links_block(params)}

      "backlinks" ->
        {:ok, create_backlinks_block(params)}

      "files" ->
        {:ok, create_files_block(params)}

      "related" ->
        {:ok, create_related_block(params)}

      _ ->
        :skip
    end
  end

  defp parse_block_header(content) do
    case String.split(content, "\n", parts: 2) do
      [header, rest] ->
        parts = String.split(header, " ", parts: 2)

        case parts do
          [type, params_string] ->
            params = parse_params(params_string)
            {type, params, rest}

          [type] ->
            {type, [], rest}
        end

      [header] ->
        {header, [], ""}
    end
  end

  defp parse_params(params_string) do
    parts = String.split(params_string)

    parts
    |> Enum.with_index()
    |> Enum.reduce([], fn
      {":" <> key, idx}, acc ->
        # Look ahead for the value
        value =
          case Enum.at(parts, idx + 1) do
            nil -> true
            # Next is another key
            ":" <> _ -> true
            val -> val
          end

        [{String.to_atom(key), value} | acc]

      _, acc ->
        acc
    end)
    |> Enum.reverse()
  end

  defp create_links_block(params) do
    %DenoteBlock{
      type: :links,
      params: params,
      content: []
    }
  end

  defp create_backlinks_block(params) do
    %DenoteBlock{
      type: :backlinks,
      params: params,
      content: []
    }
  end

  defp create_files_block(params) do
    %DenoteBlock{
      type: :files,
      params: params,
      content: []
    }
  end

  defp create_related_block(params) do
    %DenoteBlock{
      type: :related,
      params: params,
      content: []
    }
  end

  defp denote_filename?(content) do
    # Check for various Denote filename patterns
    Regex.match?(~r/^\d{8}T\d{6}/, content) or
      Regex.match?(~r/^@@\d{8}T\d{6}/, content)
  end

  defp parse_denote_filename(content, _context) do
    case extract_filename_components(content) do
      {:ok, components} ->
        {:ok, components}

      :error ->
        :skip
    end
  end

  defp extract_filename_components(filename) do
    # Remove extension(s) - handles .org, .org.gpg, etc.
    base = remove_extensions(filename)

    # Try different patterns based on separators
    cond do
      # Full format: @@ID==SIGNATURE--TITLE__KEYWORDS
      String.contains?(base, "@@") ->
        parse_full_format(base)

      # Standard format without @@: ID==SIGNATURE--TITLE__KEYWORDS or ID--TITLE__KEYWORDS
      Regex.match?(~r/^\d{8}T\d{6}/, base) ->
        parse_standard_format(base)

      true ->
        :error
    end
  end

  defp parse_full_format(base) do
    # @@ID==SIGNATURE--TITLE__KEYWORDS
    with [_, rest] <- String.split(base, "@@", parts: 2),
         {:ok, id, rest} <- extract_id(rest),
         {:ok, signature, rest} <- extract_signature(rest),
         {:ok, title, keywords} <- extract_title_and_keywords(rest) do
      {:ok,
       %FilenameComponents{
         id: id,
         signature: signature,
         title: unslugify(title),
         keywords: keywords,
         extension: ".org"
       }}
    else
      _ -> :error
    end
  end

  defp parse_standard_format(base) do
    # ID==SIGNATURE--TITLE__KEYWORDS or ID--TITLE__KEYWORDS
    with {:ok, id, rest} <- extract_id(base),
         {:ok, signature, rest} <- extract_signature(rest),
         {:ok, title, keywords} <- extract_title_and_keywords(rest) do
      {:ok,
       %FilenameComponents{
         id: id,
         signature: signature,
         title: unslugify(title),
         keywords: keywords,
         extension: ".org"
       }}
    else
      _ -> :error
    end
  end

  defp extract_id(content) do
    case Regex.run(~r/^(\d{8}T\d{6})(.*)/, content) do
      [_, id, rest] -> {:ok, id, rest}
      _ -> :error
    end
  end

  defp extract_signature(content) do
    cond do
      String.starts_with?(content, "==") ->
        case String.split(content, "--", parts: 2) do
          [sig_part, rest] ->
            signature = String.slice(sig_part, 2..-1//1)
            {:ok, signature, rest}

          _ ->
            {:ok, nil, content}
        end

      String.starts_with?(content, "--") ->
        {:ok, nil, String.slice(content, 2..-1//1)}

      true ->
        {:ok, nil, content}
    end
  end

  defp extract_title_and_keywords(content) do
    case String.split(content, "__", parts: 2) do
      [title, keywords_str] ->
        keywords = String.split(keywords_str, "_")
        {:ok, title, keywords}

      [title] ->
        {:ok, title, []}
    end
  end

  defp remove_extensions(filename) do
    # Handle multiple extensions like .org.gpg
    filename
    |> String.replace(~r/\.org\.gpg$/, "")
    |> String.replace(~r/\.org\.age$/, "")
    |> String.replace(~r/\.org$/, "")
    |> String.replace(~r/\.md$/, "")
    |> String.replace(~r/\.txt$/, "")
  end

  defp keywords_to_org_tags([]), do: ""

  defp keywords_to_org_tags(keywords) do
    ":" <> Enum.join(keywords, ":") <> ":"
  end

  defp org_tags_to_keywords(nil), do: []
  defp org_tags_to_keywords(""), do: []

  defp org_tags_to_keywords(tags) when is_binary(tags) do
    tags
    |> String.trim(":")
    |> String.split(":")
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_denote_timestamp(id) do
    # Convert YYYYMMDDTHHMMSS to Org timestamp
    case id do
      <<year::binary-4, month::binary-2, day::binary-2, "T", hour::binary-2, minute::binary-2, _second::binary-2>> ->
        "[#{year}-#{month}-#{day} #{format_weekday(year, month, day)} #{hour}:#{minute}]"

      _ ->
        nil
    end
  end

  defp format_weekday(_year, _month, _day) do
    # Simple weekday calculation (would need proper implementation)
    # For now, return a placeholder
    "Mon"
  end

  defp format_denote_id(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_iso8601(:basic)
    |> String.slice(0..14)
    |> String.replace("-", "")
    |> String.replace(":", "")
  end

  defp slugify(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end

  defp unslugify(slug) do
    slug
    |> String.replace("-", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp extract_denote_links(_document) do
    # Would traverse the document structure to find all denote links
    # This needs proper implementation based on document structure
    []
  end

  defp document_to_text(_document) do
    # Convert document to plain text for searching
    # This needs proper implementation based on document structure
    ""
  end
end
