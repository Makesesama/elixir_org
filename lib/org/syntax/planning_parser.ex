defmodule Org.Syntax.PlanningParser do
  @moduledoc """
  NimbleParsec-backed parser for Org planning lines.

  Planning lines contain one or more `SCHEDULED:`, `DEADLINE:`, or `CLOSED:`
  entries followed by Org timestamps. The parser extracts timestamp strings and
  converts them through `Org.Timestamp.parse/1`, preserving invalid timestamp
  strings for backwards compatibility with the previous parser behaviour.
  """

  import NimbleParsec

  whitespace = ignore(repeat(ascii_char([?\s, ?\t])))
  required_whitespace = ignore(times(ascii_char([?\s, ?\t]), min: 1))

  key =
    choice([
      string("SCHEDULED") |> replace(:scheduled),
      string("DEADLINE") |> replace(:deadline),
      string("CLOSED") |> replace(:closed)
    ])

  active_timestamp =
    string("<")
    |> utf8_string([not: ?>], min: 1)
    |> string(">")
    |> post_traverse({__MODULE__, :wrap_timestamp, []})

  inactive_timestamp =
    string("[")
    |> utf8_string([not: ?]], min: 1)
    |> string("]")
    |> post_traverse({__MODULE__, :wrap_timestamp, []})

  planning_item =
    key
    |> ignore(string(":"))
    |> concat(whitespace)
    |> choice([active_timestamp, inactive_timestamp])
    |> post_traverse({__MODULE__, :wrap_item, []})

  planning_line =
    whitespace
    |> concat(planning_item)
    |> repeat(required_whitespace |> concat(planning_item))
    |> optional(whitespace)

  defparsec(:planning_line_parser, planning_line)

  @spec parse_line(String.t()) :: {:ok, map()} | :error
  def parse_line(line) when is_binary(line) do
    case planning_line_parser(line) do
      {:ok, parts, "", _context, _line, _offset} ->
        {:ok, build_metadata(parts)}

      _ ->
        parse_legacy_single_item(line)
    end
  end

  def parse_line(_), do: :error

  defp parse_legacy_single_item(line) do
    case Regex.run(~r/^\s*(SCHEDULED|DEADLINE|CLOSED):\s*(.*)\s*$/, line) do
      [_, key, value] ->
        {:ok, %{planning_key(key) => String.trim(value)}}

      nil ->
        :error
    end
  end

  def wrap_timestamp(rest, args, context, _line, _offset) do
    raw =
      args
      |> Enum.reverse()
      |> Enum.join("")

    {rest, [{:timestamp, raw}], context}
  end

  def wrap_item(rest, args, context, _line, _offset) do
    case args do
      [{:timestamp, raw}, key] -> {rest, [{key, raw}], context}
      [key, {:timestamp, raw}] -> {rest, [{key, raw}], context}
    end
  end

  defp build_metadata(parts) do
    Enum.reduce(parts, %{}, fn
      {key, raw}, acc when key in [:scheduled, :deadline, :closed] ->
        Map.put(acc, key, parse_timestamp_or_raw(raw))

      _other, acc ->
        acc
    end)
  end

  defp parse_timestamp_or_raw(timestamp_str) do
    case Org.Timestamp.parse(timestamp_str) do
      {:ok, timestamp} -> timestamp
      {:error, _reason} -> timestamp_str
    end
  end

  defp planning_key("SCHEDULED"), do: :scheduled
  defp planning_key("DEADLINE"), do: :deadline
  defp planning_key("CLOSED"), do: :closed
end
