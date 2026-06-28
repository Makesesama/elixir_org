defmodule Org.Syntax.InlineMarkupParser do
  @moduledoc """
  NimbleParsec-backed parser for the conservative inline markup subset currently
  supported by `Org.FormattedText`.

  This intentionally does not attempt to implement the full Org inline object
  grammar or nested markup rules. It parses one bounded markup span at the start
  of a string.
  """

  import NimbleParsec

  defcombinatorp(
    :bold,
    ignore(string("*"))
    |> utf8_string([not: ?*, not: ?\n], min: 1)
    |> ignore(string("*"))
    |> unwrap_and_tag(:content)
    |> tag(:bold)
  )

  defcombinatorp(
    :italic,
    ignore(string("/"))
    |> utf8_string([not: ?/, not: ?\n], min: 1)
    |> ignore(string("/"))
    |> unwrap_and_tag(:content)
    |> tag(:italic)
  )

  defcombinatorp(
    :underline,
    ignore(string("_"))
    |> utf8_string([not: ?_, not: ?\n], min: 1)
    |> ignore(string("_"))
    |> unwrap_and_tag(:content)
    |> tag(:underline)
  )

  defcombinatorp(
    :code,
    ignore(string("="))
    |> utf8_string([not: ?=, not: ?\n], min: 1)
    |> ignore(string("="))
    |> unwrap_and_tag(:content)
    |> tag(:code)
  )

  defcombinatorp(
    :verbatim,
    ignore(string("~"))
    |> utf8_string([not: ?~, not: ?\n], min: 1)
    |> ignore(string("~"))
    |> unwrap_and_tag(:content)
    |> tag(:verbatim)
  )

  defcombinatorp(
    :strikethrough,
    ignore(string("+"))
    |> utf8_string([not: ?+, not: ?\n], min: 1)
    |> ignore(string("+"))
    |> unwrap_and_tag(:content)
    |> tag(:strikethrough)
  )

  defparsec(
    :markup_prefix,
    choice([
      parsec(:bold),
      parsec(:italic),
      parsec(:underline),
      parsec(:code),
      parsec(:verbatim),
      parsec(:strikethrough)
    ])
  )

  @type parsed_markup :: %{format: atom(), content: String.t(), raw: String.t()}

  @spec parse_prefix(String.t()) :: {:ok, parsed_markup(), String.t()} | :error
  def parse_prefix(text) when is_binary(text) do
    case markup_prefix(text) do
      {:ok, [{format, fields}], rest, _context, _line, _offset} ->
        raw_length = byte_size(text) - byte_size(rest)
        {:ok, %{format: format, content: fields[:content], raw: binary_part(text, 0, raw_length)}, rest}

      _ ->
        :error
    end
  end

  def parse_prefix(_), do: :error
end
