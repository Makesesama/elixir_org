defmodule Org.Syntax.KeywordParser do
  @moduledoc """
  NimbleParsec-backed parser for Org keyword lines.

  Parses bounded `#+KEY: value` fragments and returns key/value tuples.
  Higher-level modules decide whether a keyword is a file property,
  directive, comment, or some other Org construct.
  """

  import NimbleParsec

  whitespace = ignore(repeat(ascii_char([?\s, ?\t])))

  key =
    ascii_char([?A..?Z, ?a..?z, ?_])
    |> repeat(ascii_char([?A..?Z, ?a..?z, ?0..?9, ?_]))
    |> reduce({List, :to_string, []})

  value = utf8_string([not: ?\n], min: 0)

  keyword_line =
    ignore(string("#+"))
    |> concat(key)
    |> concat(whitespace)
    |> ignore(string(":"))
    |> concat(whitespace)
    |> concat(value)

  defparsec(:keyword, keyword_line)

  @spec parse_line(String.t()) :: {:ok, {String.t(), String.t()}} | :error
  def parse_line(line) when is_binary(line) do
    case keyword(String.trim(line)) do
      {:ok, [key, value], "", _context, _line, _offset} ->
        {:ok, {key, String.trim(value)}}

      _ ->
        :error
    end
  end

  def parse_line(_), do: :error
end
