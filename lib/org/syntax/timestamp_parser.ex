defmodule Org.Syntax.TimestampParser do
  @moduledoc """
  NimbleParsec-backed parser for Org timestamps.

  Returns a neutral map with basic timestamp parts so higher-level modules
  can keep their own struct/validation logic.
  """

  import NimbleParsec

  @units %{?h => :hour, ?d => :day, ?w => :week, ?m => :month, ?y => :year}

  whitespace = ignore(repeat(ascii_char([?\s, ?\t])))

  date_raw =
    integer(4)
    |> ignore(string("-"))
    |> integer(2)
    |> ignore(string("-"))
    |> integer(2)

  time_raw =
    integer(2)
    |> ignore(string(":"))
    |> integer(2)

  day_name =
    ascii_string([?A..?Z, ?a..?z], min: 1)
    |> post_traverse({__MODULE__, :wrap_day_name, []})

  date =
    date_raw
    |> post_traverse({__MODULE__, :wrap_date, []})

  time =
    time_raw
    |> post_traverse({__MODULE__, :wrap_time, []})

  time_range =
    time_raw
    |> ignore(string("-"))
    |> concat(time_raw)
    |> post_traverse({__MODULE__, :wrap_time_range, []})

  timezone_offset =
    choice([
      choice([string("+"), string("-")])
      |> ascii_char([?0..?9])
      |> ascii_char([?0..?9])
      |> string(":")
      |> ascii_char([?0..?9])
      |> ascii_char([?0..?9]),
      choice([string("+"), string("-")])
      |> ascii_char([?0..?9])
      |> ascii_char([?0..?9])
      |> ascii_char([?0..?9])
      |> ascii_char([?0..?9])
    ])
    |> post_traverse({__MODULE__, :wrap_timezone_offset, []})

  timezone_name =
    ascii_string([?A..?Z], min: 2, max: 4)
    |> post_traverse({__MODULE__, :wrap_timezone_name, []})

  timezone = choice([timezone_offset, timezone_name])

  repeater_prefix = choice([string("++"), string(".+"), string("+")])

  repeater =
    repeater_prefix
    |> integer(min: 1)
    |> ascii_char([?h, ?d, ?w, ?m, ?y])
    |> post_traverse({__MODULE__, :wrap_repeater, []})

  warning_prefix = choice([string("--"), string("-")])

  warning =
    warning_prefix
    |> integer(min: 1)
    |> ascii_char([?h, ?d, ?w, ?m, ?y])
    |> post_traverse({__MODULE__, :wrap_warning, []})

  timestamp_body =
    date
    |> optional(concat(whitespace, day_name))
    |> optional(concat(whitespace, choice([time_range, time])))
    |> optional(concat(whitespace, timezone))
    |> optional(concat(whitespace, repeater))
    |> optional(concat(whitespace, warning))
    |> optional(whitespace)

  active_timestamp =
    string("<")
    |> replace(:active)
    |> concat(timestamp_body)
    |> ignore(string(">"))

  inactive_timestamp =
    string("[")
    |> replace(:inactive)
    |> concat(timestamp_body)
    |> ignore(string("]"))

  defparsec(:timestamp, choice([active_timestamp, inactive_timestamp]))

  @spec parse(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse(timestamp_str) when is_binary(timestamp_str) do
    trimmed = String.trim(timestamp_str)

    case timestamp(trimmed) do
      {:ok, parts, "", _context, _line, _offset} ->
        build_timestamp(parts)

      {:ok, _parts, rest, _context, _line, _offset} ->
        {:error, "Invalid timestamp format: unexpected trailing content #{inspect(rest)}"}

      {:error, reason, _rest, _context, _line, _offset} ->
        {:error, reason}
    end
  end

  def parse(_), do: {:error, "Invalid timestamp format"}

  defp build_timestamp(parts) when is_list(parts) do
    base = %{
      type: nil,
      date: nil,
      day_name: nil,
      start_time: nil,
      end_time: nil,
      timezone: nil,
      repeater: nil,
      warning: nil
    }

    timestamp =
      parts
      |> Enum.reduce(base, fn
        :active, acc -> %{acc | type: :active}
        :inactive, acc -> %{acc | type: :inactive}
        {:date, date}, acc -> %{acc | date: date}
        {:day_name, day_name}, acc -> %{acc | day_name: day_name}
        {:start_time, time}, acc -> %{acc | start_time: time}
        {:end_time, time}, acc -> %{acc | end_time: time}
        {:timezone, timezone}, acc -> %{acc | timezone: timezone}
        {:repeater, repeater}, acc -> %{acc | repeater: repeater}
        {:warning, warning}, acc -> %{acc | warning: warning}
        _other, acc -> acc
      end)

    with :ok <- validate_positive_count(timestamp.repeater, "repeater"),
         :ok <- validate_positive_count(timestamp.warning, "warning"),
         {:ok, timestamp} <- validate_timestamp(timestamp) do
      {:ok, timestamp}
    end
  end

  defp validate_timestamp(%{type: type, date: {year, month, day}} = timestamp)
       when type in [:active, :inactive] do
    with {:ok, date} <- Date.new(year, month, day),
         {:ok, start_time} <- parse_time_tuple(timestamp.start_time),
         {:ok, end_time} <- parse_time_tuple(timestamp.end_time) do
      {:ok, %{timestamp | date: date, start_time: start_time, end_time: end_time}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_timestamp(%{date: nil}), do: {:error, "Invalid timestamp format: missing date"}
  defp validate_timestamp(_), do: {:error, "Invalid timestamp format"}

  defp validate_positive_count(nil, _label), do: :ok
  defp validate_positive_count(%{count: count}, _label) when is_integer(count) and count > 0, do: :ok
  defp validate_positive_count(%{count: count}, label), do: {:error, "Invalid #{label} count: #{count}"}

  defp parse_time_tuple(nil), do: {:ok, nil}

  defp parse_time_tuple({hour, minute}) do
    case Time.from_iso8601(pad_two(hour) <> ":" <> pad_two(minute) <> ":00") do
      {:ok, time} -> {:ok, time}
      {:error, _} -> {:error, "Invalid time format: #{pad_two(hour)}:#{pad_two(minute)}"}
    end
  end

  def wrap_date(rest, args, context, _line, _offset) do
    [day, month, year] = args
    {rest, [{:date, {year, month, day}}], context}
  end

  def wrap_day_name(rest, args, context, _line, _offset) do
    [day_name] = args
    {rest, [{:day_name, day_name}], context}
  end

  def wrap_time(rest, args, context, _line, _offset) do
    [minute, hour] = args
    {rest, [{:start_time, {hour, minute}}], context}
  end

  def wrap_time_range(rest, args, context, _line, _offset) do
    [end_minute, end_hour, start_minute, start_hour] = args

    {rest,
     [
       {:start_time, {start_hour, start_minute}},
       {:end_time, {end_hour, end_minute}}
     ], context}
  end

  def wrap_timezone_offset(rest, args, context, _line, _offset) do
    case args do
      [minute2, minute1, ":", hour2, hour1, sign] ->
        timezone = sign <> format_digits([hour1, hour2, minute1, minute2], true)
        {rest, [{:timezone, timezone}], context}

      [minute2, minute1, hour2, hour1, sign] ->
        timezone = sign <> format_digits([hour1, hour2, minute1, minute2], false)
        {rest, [{:timezone, timezone}], context}
    end
  end

  def wrap_timezone_name(rest, args, context, _line, _offset) do
    [timezone] = args
    {rest, [{:timezone, timezone}], context}
  end

  def wrap_repeater(rest, args, context, _line, _offset) do
    [unit_char, count, prefix] = args

    unit = Map.get(@units, unit_char)
    type = repeater_type(prefix)
    {rest, [{:repeater, %{count: count, unit: unit, type: type}}], context}
  end

  def wrap_warning(rest, args, context, _line, _offset) do
    [unit_char, count, _prefix] = args

    unit = Map.get(@units, unit_char)
    {rest, [{:warning, %{count: count, unit: unit}}], context}
  end

  defp format_digits([a, b, c, d], true), do: List.to_string([a, b]) <> ":" <> List.to_string([c, d])
  defp format_digits([a, b, c, d], false), do: List.to_string([a, b, c, d])

  defp repeater_type("+"), do: :regular
  defp repeater_type("++"), do: :cumulative
  defp repeater_type(".+"), do: :catch_up

  defp pad_two(int) when is_integer(int) and int < 10, do: "0#{int}"
  defp pad_two(int), do: Integer.to_string(int)
end
