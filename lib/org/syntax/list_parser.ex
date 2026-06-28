defmodule Org.Syntax.ListParser do
  @moduledoc """
  NimbleParsec-backed parser for bounded Org list item lines.

  Structural list nesting remains in higher-level parsers; this parser only
  recognizes a single list item line and extracts its marker metadata.
  """

  import NimbleParsec

  indent = ascii_string([?\s, ?\t], min: 0)
  content = optional(unwrap_and_tag(utf8_string([not: ?\n], min: 1), :content))

  unordered =
    unwrap_and_tag(indent, :indent_text)
    |> unwrap_and_tag(choice([string("-"), string("+"), string("*")]), :bullet)
    |> ignore(ascii_char([?\s, ?\t]))
    |> concat(content)

  ordered =
    unwrap_and_tag(indent, :indent_text)
    |> unwrap_and_tag(ascii_string([?0..?9], min: 1), :number_text)
    |> ignore(choice([string("."), string(")")]))
    |> ignore(ascii_char([?\s, ?\t]))
    |> concat(content)

  defparsec(:unordered_item, unordered)
  defparsec(:ordered_item, ordered)

  @type parsed_item :: %{
          indent: non_neg_integer(),
          ordered: boolean(),
          number: non_neg_integer() | nil,
          bullet: String.t(),
          content: String.t()
        }

  @spec parse_line(String.t(), keyword()) :: {:ok, parsed_item()} | :error
  def parse_line(line, opts \\ [])

  def parse_line(line, opts) when is_binary(line) do
    allow_star = Keyword.get(opts, :allow_star, true)

    case ordered_item(line) do
      {:ok, fields, "", _context, _line, _offset} ->
        {:ok, build_ordered(fields)}

      _ ->
        parse_unordered(line, allow_star)
    end
  end

  def parse_line(_, _), do: :error

  @spec list_item?(String.t(), keyword()) :: boolean()
  def list_item?(line, opts \\ []), do: match?({:ok, _}, parse_line(line, opts))

  defp parse_unordered(line, allow_star) do
    case unordered_item(line) do
      {:ok, fields, "", _context, _line, _offset} ->
        item = build_unordered(fields)

        if allow_star or item.bullet != "*" do
          {:ok, item}
        else
          :error
        end

      _ ->
        :error
    end
  end

  defp build_ordered(fields) do
    %{
      indent: indent_length(fields[:indent_text]),
      ordered: true,
      number: String.to_integer(fields[:number_text]),
      bullet: fields[:number_text] <> ".",
      content: fields[:content] || ""
    }
  end

  defp build_unordered(fields) do
    %{
      indent: indent_length(fields[:indent_text]),
      ordered: false,
      number: nil,
      bullet: fields[:bullet],
      content: fields[:content] || ""
    }
  end

  defp indent_length(indent_text), do: String.length(indent_text || "")
end
