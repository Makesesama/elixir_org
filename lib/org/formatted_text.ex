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
  @type span :: String.t() | %__MODULE__.Span{}
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

  # Parse spans recursively
  defp parse_spans("", acc), do: acc

  defp parse_spans(text, acc) do
    case find_next_format(text) do
      nil ->
        # No more formatting found, add remaining text
        if text != "", do: acc ++ [text], else: acc

      {format, content, before, after_text} ->
        # Add text before the format (if any)
        acc = if before != "", do: acc ++ [before], else: acc
        # Add the formatted span
        acc = acc ++ [span(format, content)]
        # Continue parsing the remaining text
        parse_spans(after_text, acc)
    end
  end

  # Find the next formatting pattern in the text
  defp find_next_format(text) do
    @formatting_patterns
    |> Enum.map(fn {format, regex} ->
      case Regex.run(regex, text, return: :index) do
        [{start, _}, {content_start, content_length}] ->
          before = String.slice(text, 0, start)
          content = String.slice(text, content_start, content_length)
          # +2 for the delimiters
          after_pos = start + (content_length + 2)
          after_text = String.slice(text, after_pos..-1//1)
          {start, format, content, before, after_text}

        nil ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.min_by(fn {start, _, _, _, _} -> start end, fn -> nil end)
    |> case do
      nil -> nil
      {_start, format, content, before, after_text} -> {format, content, before, after_text}
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

  defp span_to_string(text) when is_binary(text), do: text
end
