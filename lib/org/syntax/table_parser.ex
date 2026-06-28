defmodule Org.Syntax.TableParser do
  @moduledoc """
  Parser helpers for bounded Org table rows.

  The higher-level parsers own table grouping and structure. This module is the
  single source for row detection and cell extraction.
  """

  @spec parse_row(String.t(), keyword()) :: {:ok, list(String.t())} | :separator | :error
  def parse_row(line, opts \\ [])

  def parse_row(line, opts) when is_binary(line) do
    trimmed = String.trim(line)

    cond do
      not (String.starts_with?(trimmed, "|") and String.ends_with?(trimmed, "|")) ->
        :error

      separator?(trimmed, Keyword.get(opts, :plus_separator, false)) ->
        :separator

      true ->
        cells =
          trimmed
          |> String.slice(1..-2//1)
          |> String.split("|")
          |> Enum.map(&String.trim/1)

        {:ok, cells}
    end
  end

  def parse_row(_, _), do: :error

  @spec row?(String.t(), keyword()) :: boolean()
  def row?(line, opts \\ []), do: match?({:ok, _}, parse_row(line, opts)) or parse_row(line, opts) == :separator

  defp separator?(trimmed, plus_separator) do
    allowed = if plus_separator, do: ["|", "-", "+", " ", "\t"], else: ["|", "-", " ", "\t"]

    trimmed
    |> String.graphemes()
    |> Enum.all?(&(&1 in allowed))
  end
end
