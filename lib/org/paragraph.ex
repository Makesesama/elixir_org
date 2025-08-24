defmodule Org.Paragraph do
  defstruct lines: []

  @type line :: String.t() | Org.FormattedText.t()
  @type t :: %Org.Paragraph{
          lines: list(line)
        }

  @moduledoc ~S"""
  Represents an uninterrupted list of lines. Paragraphs are separated by one or more newlines.

  Example:
      iex> doc = Org.Parser.parse("Foo\nBar\n\nBaz")
      iex> doc.contents
      [%Org.Paragraph{lines: ["Foo", "Bar"]}, %Org.Paragraph{lines: ["Baz"]}]
  """

  @doc "Constructs a new paragraph from given list of lines"
  @spec new(list(line)) :: t
  def new(lines) do
    %Org.Paragraph{lines: lines}
  end

  @doc "Prepends a line to the list of lines. Used by the parser."
  @spec prepend_line(t, String.t()) :: t
  def prepend_line(paragraph, line) do
    formatted_line = parse_line_formatting(line)
    %Org.Paragraph{paragraph | lines: [formatted_line | paragraph.lines]}
  end

  @doc "Creates a new paragraph with formatted text parsing"
  @spec new_formatted(list(String.t())) :: t
  def new_formatted(lines) when is_list(lines) do
    formatted_lines = Enum.map(lines, &parse_line_formatting/1)
    %Org.Paragraph{lines: formatted_lines}
  end

  @doc "Parses formatting in a text line and returns FormattedText if formatting is found, otherwise returns the plain string"
  @spec parse_line_formatting(String.t()) :: line
  def parse_line_formatting(line) when is_binary(line) do
    case has_formatting?(line) do
      true -> Org.FormattedText.parse(line)
      false -> line
    end
  end

  # Check if a line contains any formatting markers
  defp has_formatting?(line) do
    formatting_patterns = [
      # *bold*
      ~r/\*[^*]+\*/,
      # /italic/
      ~r/\/[^\/]+\//,
      # _underline_
      ~r/_[^_]+_/,
      # =code=
      ~r/=[^=]+=/,
      # ~verbatim~
      ~r/~[^~]+~/,
      # +strikethrough+
      ~r/\+[^\+]+\+/
    ]

    Enum.any?(formatting_patterns, &Regex.match?(&1, line))
  end
end
