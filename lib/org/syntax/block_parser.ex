defmodule Org.Syntax.BlockParser do
  @moduledoc """
  NimbleParsec-backed parser for Org block marker lines.

  This parser only extracts metadata from bounded block header/end marker lines.
  Structural block collection remains with the higher-level parser.
  """

  import NimbleParsec

  body =
    ignore(string("#+"))
    |> utf8_string([not: ?\n], min: 1)

  defparsec(:block_marker, body)

  @type block_marker ::
          %{
            type: :begin_src,
            lang: String.t(),
            params: String.t()
          }
          | %{type: :end_src}
          | %{
              type: :begin_dynamic,
              name: String.t(),
              params: String.t(),
              end_marker: String.t()
            }
          | %{type: :end_dynamic}
          | %{
              type: :begin_block,
              name: String.t(),
              params: String.t(),
              end_marker: String.t()
            }
          | %{type: :end_block, name: String.t()}

  @spec parse_line(String.t()) :: {:ok, block_marker()} | :error
  def parse_line(line) when is_binary(line) do
    case block_marker(String.trim(line)) do
      {:ok, [body], "", _context, _line, _offset} -> parse_body(body)
      _ -> :error
    end
  end

  def parse_line(_), do: :error

  def begin_src?(line), do: match?({:ok, %{type: :begin_src}}, parse_line(line))
  def end_src?(line), do: match?({:ok, %{type: :end_src}}, parse_line(line))

  defp parse_body(body) do
    trimmed = String.trim(body)
    upper = String.upcase(trimmed)

    cond do
      upper == "END_SRC" ->
        {:ok, %{type: :end_src}}

      String.starts_with?(upper, "BEGIN_SRC") ->
        parse_begin_src(trimmed)

      upper == "END:" ->
        {:ok, %{type: :end_dynamic}}

      String.starts_with?(upper, "BEGIN:") ->
        parse_begin_dynamic(trimmed)

      String.starts_with?(upper, "BEGIN_") ->
        parse_begin_block(trimmed)

      String.starts_with?(upper, "END_") ->
        parse_end_block(trimmed)

      true ->
        :error
    end
  end

  defp parse_begin_src(body) do
    rest = body |> String.slice(String.length("BEGIN_SRC")..-1//1) |> String.trim()
    {lang, params} = split_first_word(rest)
    {:ok, %{type: :begin_src, lang: lang, params: params}}
  end

  defp parse_begin_dynamic(body) do
    rest = body |> String.slice(String.length("BEGIN:")..-1//1) |> String.trim()
    {name, params} = split_first_word(rest)
    {:ok, %{type: :begin_dynamic, name: name, params: params, end_marker: "#+END:"}}
  end

  defp parse_begin_block(body) do
    rest = String.slice(body, String.length("BEGIN_")..-1//1)
    {name, params} = split_first_word(rest)
    normalized_name = String.upcase(name)

    if normalized_name == "" do
      :error
    else
      {:ok, %{type: :begin_block, name: normalized_name, params: params, end_marker: "#+END_#{normalized_name}"}}
    end
  end

  defp parse_end_block(body) do
    name = body |> String.slice(String.length("END_")..-1//1) |> String.trim() |> String.upcase()

    if name == "" do
      :error
    else
      {:ok, %{type: :end_block, name: name}}
    end
  end

  defp split_first_word(""), do: {"", ""}

  defp split_first_word(text) do
    case String.split(String.trim(text), ~r/\s+/, parts: 2) do
      [word, rest] -> {word, String.trim(rest)}
      [word] -> {word, ""}
    end
  end
end
