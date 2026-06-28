defmodule Org.Syntax.PropertyParser do
  @moduledoc """
  NimbleParsec-backed parser for Org property drawer entries.

  Parses bounded `:KEY: value` fragments and returns trimmed key/value tuples.
  Drawer start/end recognition remains with the structural parser.
  """

  import NimbleParsec

  whitespace = ignore(repeat(ascii_char([?\s, ?\t])))

  key = utf8_string([not: ?:, not: ?\n], min: 1)
  value = utf8_string([not: ?\n], min: 0)

  property_line =
    ignore(string(":"))
    |> concat(key)
    |> ignore(string(":"))
    |> concat(whitespace)
    |> concat(value)

  defparsec(:property, property_line)

  @spec parse_line(String.t()) :: {:ok, {String.t(), String.t()}} | :error
  def parse_line(line) when is_binary(line) do
    case property(String.trim(line)) do
      {:ok, [key, value], "", _context, _line, _offset} ->
        {:ok, {String.trim(key), String.trim(value)}}

      _ ->
        :error
    end
  end

  def parse_line(_), do: :error
end
