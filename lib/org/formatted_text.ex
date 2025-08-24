defmodule Org.FormattedText do
  @moduledoc """
  Represents formatted text with inline markup like bold, italic, etc.

  Formatted text is composed of spans, where each span can be:
  - Plain text (string)
  - Formatted text with a specific format type

  Supported formats:
  - *bold*
  - /italic/
  - _underline_
  - =code=
  - ~verbatim~
  - +strikethrough+
  """

  defstruct spans: []

  @type format_type :: :bold | :italic | :underline | :code | :verbatim | :strikethrough
  @type span :: String.t() | %__MODULE__.Span{} | %__MODULE__.Link{}
  @type t :: %__MODULE__{spans: list(span)}

  defmodule Span do
    @moduledoc """
    Represents a formatted text span with a specific format type.
    """

    defstruct [:format, :content]

    @type t :: %__MODULE__{
            format: Org.FormattedText.format_type(),
            content: String.t()
          }
  end

  defmodule Link do
    @moduledoc """
    Represents a link with URL and optional description text.
    """

    defstruct [:url, :description]

    @type t :: %__MODULE__{
            url: String.t(),
            description: String.t() | nil
          }
  end

  @doc """
  Creates a new formatted text from a list of spans.
  """
  @spec new(list(span)) :: t()
  def new(spans \\ []) do
    %__MODULE__{spans: spans}
  end

  @doc """
  Creates a new formatted span.
  """
  @spec span(format_type(), String.t()) :: Span.t()
  def span(format, content) do
    %Span{format: format, content: content}
  end

  @doc """
  Creates a new link.
  """
  @spec link(String.t(), String.t() | nil) :: Link.t()
  def link(url, description \\ nil) do
    %Link{url: url, description: description}
  end

  @doc """
  Parses a text string and extracts formatting spans.

  Examples:
      iex> Org.FormattedText.parse("This is *bold* and /italic/ text")
      %Org.FormattedText{
        spans: [
          "This is ",
          %Org.FormattedText.Span{format: :bold, content: "bold"},
          " and ",
          %Org.FormattedText.Span{format: :italic, content: "italic"},
          " text"
        ]
      }
  """
  @spec parse(String.t()) :: t()
  def parse(text) when is_binary(text) do
    spans = parse_spans(text, [])
    %__MODULE__{spans: spans}
  end

  @doc """
  Converts formatted text back to org-mode markup string.
  """
  @spec to_org_string(t()) :: String.t()
  def to_org_string(%__MODULE__{spans: spans}) do
    Enum.map_join(spans, "", &span_to_string/1)
  end

  @doc """
  Converts formatted text to plain text (removes all formatting).
  """
  @spec to_plain_text(t()) :: String.t()
  def to_plain_text(%__MODULE__{spans: spans}) do
    Enum.map_join(spans, "", fn
      %Span{content: content} -> content
      %Link{description: nil, url: url} -> url
      %Link{description: description} -> description
      text when is_binary(text) -> text
    end)
  end

  @doc """
  Checks if the formatted text is empty or contains only whitespace.
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{spans: spans}) do
    spans == [] or
      Enum.all?(spans, fn
        %Span{content: content} -> String.trim(content) == ""
        %Link{description: nil, url: url} -> String.trim(url) == ""
        %Link{description: description} -> String.trim(description) == ""
        text when is_binary(text) -> String.trim(text) == ""
      end)
  end

  # Private implementation

  # Regex patterns for different formatting types
  @formatting_patterns %{
    bold: ~r/\*([^*]+)\*/,
    italic: ~r/\/([^\/]+)\//,
    underline: ~r/_([^_]+)_/,
    code: ~r/=([^=]+)=/,
    verbatim: ~r/~([^~]+)~/,
    strikethrough: ~r/\+([^\+]+)\+/
  }

  # Link patterns (processed separately due to different structure)
  @link_patterns %{
    # [[URL][description]] - link with description
    described_link: ~r/\[\[([^\[\]]+)\]\[([^\[\]]+)\]\]/,
    # [[URL]] - simple link
    simple_link: ~r/\[\[([^\[\]]+)\]\]/,
    # Bare URLs (http/https)
    bare_url: ~r/(https?:\/\/[^\s\[\]]+)/
  }

  # Parse spans recursively
  defp parse_spans("", acc), do: acc

  defp parse_spans(text, acc) do
    case find_next_format_or_link(text) do
      nil ->
        # No more formatting found, add remaining text
        if text != "", do: acc ++ [text], else: acc

      {:format, format, content, before, after_text} ->
        # Add text before the format (if any)
        acc = if before != "", do: acc ++ [before], else: acc
        # Add the formatted span
        acc = acc ++ [span(format, content)]
        # Continue parsing the remaining text
        parse_spans(after_text, acc)

      {:link, url, description, before, after_text} ->
        # Add text before the link (if any)
        acc = if before != "", do: acc ++ [before], else: acc
        # Add the link
        acc = acc ++ [link(url, description)]
        # Continue parsing the remaining text
        parse_spans(after_text, acc)
    end
  end

  # Find the next formatting pattern or link in the text
  defp find_next_format_or_link(text) do
    format_matches = find_format_matches(text)
    link_matches = find_link_matches(text)

    # Combine and find the earliest match
    (format_matches ++ link_matches)
    |> Enum.min_by(fn {start, _} -> start end, fn -> nil end)
    |> case do
      nil -> nil
      {_start, match_data} -> match_data
    end
  end

  defp find_format_matches(text) do
    @formatting_patterns
    |> Enum.map(fn {format, regex} ->
      case Regex.run(regex, text, return: :index) do
        [{start, _}, {content_start, content_length}] ->
          before = String.slice(text, 0, start)
          content = String.slice(text, content_start, content_length)
          # +2 for the delimiters
          after_pos = start + (content_length + 2)
          after_text = String.slice(text, after_pos..-1//1)
          {start, {:format, format, content, before, after_text}}

        nil ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp find_link_matches(text) do
    @link_patterns
    |> Enum.map(&process_link_match(&1, text))
    |> Enum.reject(&is_nil/1)
  end

  defp process_link_match({link_type, regex}, text) do
    case {link_type, Regex.run(regex, text, return: :index)} do
      {_, nil} ->
        nil

      {:described_link, [{start, total_length}, {url_start, url_length}, {desc_start, desc_length}]} ->
        before = String.slice(text, 0, start)
        url = String.slice(text, url_start, url_length)
        description = String.slice(text, desc_start, desc_length)
        after_pos = start + total_length
        after_text = String.slice(text, after_pos..-1//1)
        {start, {:link, url, description, before, after_text}}

      {:simple_link, [{start, total_length}, {url_start, url_length}]} ->
        before = String.slice(text, 0, start)
        url = String.slice(text, url_start, url_length)
        after_pos = start + total_length
        after_text = String.slice(text, after_pos..-1//1)
        {start, {:link, url, nil, before, after_text}}

      {:bare_url, [{start, total_length}, {url_start, url_length}]} ->
        before = String.slice(text, 0, start)
        url = String.slice(text, url_start, url_length)
        after_pos = start + total_length
        after_text = String.slice(text, after_pos..-1//1)
        {start, {:link, url, nil, before, after_text}}

      _ ->
        nil
    end
  end

  # Convert a span back to org string
  defp span_to_string(%Span{format: format, content: content}) do
    case format do
      :bold -> "*#{content}*"
      :italic -> "/#{content}/"
      :underline -> "_#{content}_"
      :code -> "=#{content}="
      :verbatim -> "~#{content}~"
      :strikethrough -> "+#{content}+"
    end
  end

  defp span_to_string(%Link{url: url, description: nil}) do
    "[[#{url}]]"
  end

  defp span_to_string(%Link{url: url, description: description}) do
    "[[#{url}][#{description}]]"
  end

  defp span_to_string(text) when is_binary(text), do: text
end
