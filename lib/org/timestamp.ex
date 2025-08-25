defmodule Org.Timestamp do
  @moduledoc """
  Parsing and handling of org-mode timestamps.

  Org-mode supports various timestamp formats:
  - Active timestamps: `<2024-01-15 Mon>` (appear in agenda)
  - Inactive timestamps: `[2024-01-15 Mon]` (do not appear in agenda)
  - Times: `<2024-01-15 Mon 14:30>` or `<2024-01-15 Mon 14:30-16:00>`
  - Repeaters: `<2024-01-15 Mon +1w>` (repeat every week)
  - Warning periods: `<2024-01-15 Mon -2d>` (warn 2 days before)
  - Date ranges: `<2024-01-15 Mon>--<2024-01-20 Sat>`
  """

  @type timestamp_type :: :active | :inactive
  @type repeater_unit :: :hour | :day | :week | :month | :year
  @type warning_unit :: :hour | :day | :week | :month | :year

  @type repeater :: %{
          count: pos_integer(),
          unit: repeater_unit()
        }

  @type warning :: %{
          count: pos_integer(),
          unit: warning_unit()
        }

  defstruct [
    :type,
    :date,
    :start_time,
    :end_time,
    :day_name,
    :repeater,
    :warning,
    :raw
  ]

  @type t :: %__MODULE__{
          type: timestamp_type(),
          date: Date.t(),
          start_time: Time.t() | nil,
          end_time: Time.t() | nil,
          day_name: String.t() | nil,
          repeater: repeater() | nil,
          warning: warning() | nil,
          raw: String.t()
        }

  @doc """
  Parses an org-mode timestamp string into a structured format.

  ## Examples

      iex> Org.Timestamp.parse("<2024-01-15 Mon>")
      {:ok, %Org.Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        day_name: "Mon",
        raw: "<2024-01-15 Mon>"
      }}

      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon 14:30-16:00>")
      iex> timestamp.type
      :active
      iex> timestamp.date
      ~D[2024-01-15]
      iex> timestamp.start_time
      ~T[14:30:00]
      iex> timestamp.end_time
      ~T[16:00:00]
      iex> timestamp.day_name
      "Mon"

      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1w -2d>")
      iex> timestamp.type
      :active
      iex> timestamp.date
      ~D[2024-01-15]
      iex> timestamp.repeater
      %{count: 1, unit: :week}
      iex> timestamp.warning
      %{count: 2, unit: :day}
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(timestamp_str) do
    trimmed = String.trim(timestamp_str)

    case detect_timestamp_type(trimmed) do
      {:ok, type, content} ->
        case parse_timestamp_content(content, type, trimmed) do
          {:ok, timestamp} -> {:ok, timestamp}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Parses an org-mode timestamp, raising on error.
  """
  @spec parse!(String.t()) :: t()
  def parse!(timestamp_str) do
    case parse(timestamp_str) do
      {:ok, timestamp} -> timestamp
      {:error, reason} -> raise ArgumentError, "Invalid timestamp: #{reason}"
    end
  end

  @doc """
  Renders a timestamp back to org-mode format.
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = timestamp) do
    {open_char, close_char} = format_brackets(timestamp.type)

    parts = [
      Date.to_string(timestamp.date),
      format_day_name(timestamp.day_name),
      format_time_part(timestamp.start_time, timestamp.end_time),
      format_repeater(timestamp.repeater),
      format_warning(timestamp.warning)
    ]

    content = parts |> Enum.reject(&(&1 == "")) |> Enum.join("")
    "#{open_char}#{content}#{close_char}"
  end

  @doc """
  Checks if a timestamp is active (appears in agenda).
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{type: :active}), do: true
  def active?(%__MODULE__{type: :inactive}), do: false

  @doc """
  Checks if a timestamp has time information.
  """
  @spec has_time?(t()) :: boolean()
  def has_time?(%__MODULE__{start_time: nil}), do: false
  def has_time?(%__MODULE__{start_time: %Time{}}), do: true

  @doc """
  Checks if a timestamp has a time range.
  """
  @spec time_range?(t()) :: boolean()
  def time_range?(%__MODULE__{start_time: %Time{}, end_time: %Time{}}), do: true
  def time_range?(%__MODULE__{}), do: false

  @doc """
  Checks if a timestamp has a repeater.
  """
  @spec repeating?(t()) :: boolean()
  def repeating?(%__MODULE__{repeater: %{}}), do: true
  def repeating?(%__MODULE__{repeater: nil}), do: false

  @doc """
  Gets the DateTime representation of a timestamp.
  Returns the start time if available, otherwise noon on the date.
  """
  @spec to_datetime(t()) :: DateTime.t()
  def to_datetime(%__MODULE__{date: date, start_time: nil}) do
    # Default to noon when no time is specified
    {:ok, datetime} = DateTime.new(date, ~T[12:00:00], "Etc/UTC")
    datetime
  end

  def to_datetime(%__MODULE__{date: date, start_time: %Time{} = time}) do
    {:ok, datetime} = DateTime.new(date, time, "Etc/UTC")
    datetime
  end

  @doc """
  Gets the end DateTime for timestamps with time ranges.
  """
  @spec end_datetime(t()) :: DateTime.t() | nil
  def end_datetime(%__MODULE__{end_time: nil}), do: nil

  def end_datetime(%__MODULE__{date: date, end_time: %Time{} = end_time}) do
    {:ok, datetime} = DateTime.new(date, end_time, "Etc/UTC")
    datetime
  end

  # Private functions

  defp format_brackets(:active), do: {"<", ">"}
  defp format_brackets(:inactive), do: {"[", "]"}

  defp format_day_name(nil), do: ""
  defp format_day_name(day_name), do: " #{day_name}"

  defp format_time_part(nil, nil), do: ""

  defp format_time_part(%Time{} = start_time, nil) do
    " #{Time.to_string(start_time) |> String.slice(0..4)}"
  end

  defp format_time_part(%Time{} = start_time, %Time{} = end_time) do
    start_str = Time.to_string(start_time) |> String.slice(0..4)
    end_str = Time.to_string(end_time) |> String.slice(0..4)
    " #{start_str}-#{end_str}"
  end

  defp format_time_part(nil, %Time{}), do: ""

  defp format_repeater(nil), do: ""
  defp format_repeater(%{count: count, unit: unit}), do: " +#{count}#{unit_to_char(unit)}"

  defp format_warning(nil), do: ""
  defp format_warning(%{count: count, unit: unit}), do: " -#{count}#{unit_to_char(unit)}"

  defp detect_timestamp_type(str) do
    cond do
      String.starts_with?(str, "<") and String.ends_with?(str, ">") ->
        content = str |> String.slice(1..-2//1)
        {:ok, :active, content}

      String.starts_with?(str, "[") and String.ends_with?(str, "]") ->
        content = str |> String.slice(1..-2//1)
        {:ok, :inactive, content}

      true ->
        {:error, "Invalid timestamp format: must be enclosed in < > or [ ]"}
    end
  end

  defp parse_timestamp_content(content, type, raw) do
    # Main regex to parse timestamp components
    # Matches: YYYY-MM-DD [Day] [HH:MM[-HH:MM]] [+Nx] [-Nx]
    regex =
      ~r/^(\d{4}-\d{2}-\d{2})\s*(?:(\w+))?\s*(?:(\d{1,2}:\d{2})(?:-(\d{1,2}:\d{2}))?)?\s*(?:\+(\d+)([hdwmy]))?\s*(?:-(\d+)([hdwmy]))?$/

    case Regex.run(regex, String.trim(content)) do
      [_, date_str | rest] ->
        with {:ok, date} <- Date.from_iso8601(date_str),
             {:ok, parsed_components} <- parse_optional_components(rest) do
          timestamp = %__MODULE__{
            type: type,
            date: date,
            start_time: parsed_components.start_time,
            end_time: parsed_components.end_time,
            day_name: parsed_components.day_name,
            repeater: parsed_components.repeater,
            warning: parsed_components.warning,
            raw: raw
          }

          {:ok, timestamp}
        else
          {:error, reason} -> {:error, "Invalid date: #{reason}"}
        end

      nil ->
        {:error, "Invalid timestamp format: #{content}"}
    end
  end

  defp parse_optional_components(components) when is_list(components) do
    # Pad the list to ensure we have all 7 components (some may be empty strings or nil)
    padded = components ++ List.duplicate("", 7)

    [day_name, start_time_str, end_time_str, repeater_count, repeater_unit, warning_count, warning_unit] =
      Enum.take(padded, 7)

    with {:ok, start_time} <- parse_time_component(start_time_str),
         {:ok, end_time} <- parse_time_component(end_time_str),
         {:ok, repeater} <- parse_repeater(repeater_count, repeater_unit),
         {:ok, warning} <- parse_warning(warning_count, warning_unit) do
      {:ok,
       %{
         day_name: normalize_string(day_name),
         start_time: start_time,
         end_time: end_time,
         repeater: repeater,
         warning: warning
       }}
    end
  end

  defp parse_time_component(nil), do: {:ok, nil}
  defp parse_time_component(""), do: {:ok, nil}

  defp parse_time_component(time_str) do
    case Time.from_iso8601(time_str <> ":00") do
      {:ok, time} -> {:ok, time}
      {:error, _} -> {:error, "Invalid time format: #{time_str}"}
    end
  end

  defp parse_repeater(nil, _), do: {:ok, nil}
  defp parse_repeater("", _), do: {:ok, nil}

  defp parse_repeater(count_str, unit_str) do
    case Integer.parse(count_str) do
      {count, ""} when count > 0 ->
        case char_to_unit(unit_str) do
          {:ok, unit} -> {:ok, %{count: count, unit: unit}}
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:error, "Invalid repeater count: #{count_str}"}
    end
  end

  defp parse_warning(nil, _), do: {:ok, nil}
  defp parse_warning("", _), do: {:ok, nil}

  defp parse_warning(count_str, unit_str) do
    case Integer.parse(count_str) do
      {count, ""} when count > 0 ->
        case char_to_unit(unit_str) do
          {:ok, unit} -> {:ok, %{count: count, unit: unit}}
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:error, "Invalid warning count: #{count_str}"}
    end
  end

  defp char_to_unit("h"), do: {:ok, :hour}
  defp char_to_unit("d"), do: {:ok, :day}
  defp char_to_unit("w"), do: {:ok, :week}
  defp char_to_unit("m"), do: {:ok, :month}
  defp char_to_unit("y"), do: {:ok, :year}
  defp char_to_unit(char), do: {:error, "Unknown time unit: #{char}"}

  defp unit_to_char(:hour), do: "h"
  defp unit_to_char(:day), do: "d"
  defp unit_to_char(:week), do: "w"
  defp unit_to_char(:month), do: "m"
  defp unit_to_char(:year), do: "y"

  defp normalize_string(nil), do: nil
  defp normalize_string(""), do: nil
  defp normalize_string(str), do: String.trim(str)
end
