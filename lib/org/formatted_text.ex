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
  defp find_next_format_or_link(text), do: find_next_format_or_link(text, text, 0)

  defp find_next_format_or_link(_original, "", _offset), do: nil

  defp find_next_format_or_link(original, suffix, offset) do
    case parse_token_prefix(suffix) do
      {:format, format, content, _raw, after_text} ->
        {:format, format, content, binary_part(original, 0, offset), after_text}

      {:link, url, description, _raw, after_text} ->
        {:link, url, description, binary_part(original, 0, offset), after_text}

      :error ->
        case next_codepoint(suffix) do
          {char, rest} -> find_next_format_or_link(original, rest, offset + byte_size(char))
          nil -> nil
        end
    end
  end

  defp parse_token_prefix(text) do
    case Org.Syntax.LinkParser.parse_prefix(text) do
      {:ok, %{url: url, description: description, raw: raw}, rest} ->
        {:link, url, description, raw, rest}

      :error ->
        case Org.Syntax.InlineMarkupParser.parse_prefix(text) do
          {:ok, %{format: format, content: content, raw: raw}, rest} ->
            {:format, format, content, raw, rest}

          :error ->
            :error
        end
    end
  end

  defp next_codepoint(<<char::utf8, rest::binary>>), do: {<<char::utf8>>, rest}
  defp next_codepoint(<<char, rest::binary>>), do: {<<char>>, rest}
  defp next_codepoint(""), do: nil

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
