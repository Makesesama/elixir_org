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

  # ============================================================================
  # Repeater Calculation Functions
  # ============================================================================

  @doc """
  Calculates the next occurrence of a repeating timestamp.

  ## Examples

      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1w>")
      iex> next = Org.Timestamp.next_occurrence(timestamp)
      iex> next.date
      ~D[2024-01-22]

      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon 09:00 +1d>")
      iex> next = Org.Timestamp.next_occurrence(timestamp)
      iex> next.date
      ~D[2024-01-16]
      iex> next.start_time
      ~T[09:00:00]
  """
  @spec next_occurrence(t()) :: t() | nil
  def next_occurrence(%__MODULE__{repeater: nil}), do: nil

  def next_occurrence(%__MODULE__{repeater: repeater} = timestamp) do
    new_date = add_repeater_interval(timestamp.date, repeater)
    new_day_name = day_name_from_date(new_date)

    updated_timestamp = %{
      timestamp
      | date: new_date,
        day_name: new_day_name,
        raw: update_raw_date(timestamp.raw, new_date, new_day_name)
    }

    updated_timestamp
  end

  @doc """
  Calculates the next occurrence from a specific reference date.

  ## Examples

      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1w>")
      iex> reference = ~D[2024-01-20]
      iex> next = Org.Timestamp.next_occurrence_from(timestamp, reference)
      iex> next.date
      ~D[2024-01-22]
  """
  @spec next_occurrence_from(t(), Date.t()) :: t() | nil
  def next_occurrence_from(%__MODULE__{repeater: nil}, _reference_date), do: nil

  def next_occurrence_from(%__MODULE__{repeater: repeater} = timestamp, reference_date) do
    # Find the next occurrence after reference_date
    next_date = find_next_occurrence_after(timestamp.date, repeater, reference_date)
    new_day_name = day_name_from_date(next_date)

    updated_timestamp = %{
      timestamp
      | date: next_date,
        day_name: new_day_name,
        raw: update_raw_date(timestamp.raw, next_date, new_day_name)
    }

    updated_timestamp
  end

  @doc """
  Generates all occurrences of a repeating timestamp within a date range.

  ## Examples

      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1w>")
      iex> occurrences = Org.Timestamp.occurrences_in_range(timestamp, ~D[2024-01-10], ~D[2024-02-05])
      iex> length(occurrences)
      4
      iex> hd(occurrences).date
      ~D[2024-01-15]
  """
  @spec occurrences_in_range(t(), Date.t(), Date.t()) :: [t()]
  def occurrences_in_range(%__MODULE__{repeater: nil}, _start_date, _end_date), do: []

  def occurrences_in_range(%__MODULE__{repeater: repeater} = timestamp, start_date, end_date) do
    # Start from the original date or first occurrence on/after start_date
    first_occurrence =
      if Date.compare(timestamp.date, start_date) == :lt do
        find_next_occurrence_on_or_after(timestamp.date, repeater, start_date)
      else
        timestamp.date
      end

    # Only generate if the first occurrence is within the range
    if Date.compare(first_occurrence, end_date) != :gt do
      generate_occurrences(timestamp, first_occurrence, end_date, repeater, [])
    else
      []
    end
  end

  @doc """
  Advances a repeating timestamp to its next occurrence (typically when task is completed).

  ## Examples

      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1w>")
      iex> advanced = Org.Timestamp.advance_repeater(timestamp)
      iex> advanced.date
      ~D[2024-01-22]
  """
  @spec advance_repeater(t()) :: t()
  def advance_repeater(%__MODULE__{repeater: nil} = timestamp), do: timestamp
  def advance_repeater(timestamp), do: next_occurrence(timestamp)

  @doc """
  Checks if a timestamp should repeat on or after a given date.

  ## Examples

      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1w>")
      iex> Org.Timestamp.repeats_on_or_after?(timestamp, ~D[2024-01-22])
      true
      iex> Org.Timestamp.repeats_on_or_after?(timestamp, ~D[2024-01-10])
      true
  """
  @spec repeats_on_or_after?(t(), Date.t()) :: boolean()
  def repeats_on_or_after?(%__MODULE__{repeater: nil}, _date), do: false

  def repeats_on_or_after?(%__MODULE__{} = timestamp, target_date) do
    # Check if the original date is on or after target
    if Date.compare(timestamp.date, target_date) != :lt do
      true
    else
      # Check if any future occurrence is on or after target
      occurrences = occurrences_in_range(timestamp, target_date, Date.add(target_date, 365))
      length(occurrences) > 0
    end
  end

  @doc """
  Gets the interval in days for a repeater (approximate for months/years).

  ## Examples

      iex> Org.Timestamp.repeater_interval_days(%{count: 1, unit: :week})
      7
      iex> Org.Timestamp.repeater_interval_days(%{count: 2, unit: :day})
      2
  """
  @spec repeater_interval_days(repeater()) :: integer()
  def repeater_interval_days(%{count: count, unit: unit}) do
    base_days =
      case unit do
        # Less than a day
        :hour -> 0
        :day -> 1
        :week -> 7
        # Approximate
        :month -> 30
        # Approximate
        :year -> 365
      end

    count * base_days
  end

  # Private helper functions for repeater calculations

  defp add_repeater_interval(date, %{count: count, unit: unit}) do
    case unit do
      :hour ->
        # Hours don't affect the date, return same date
        date

      :day ->
        Date.add(date, count)

      :week ->
        Date.add(date, count * 7)

      :month ->
        add_months(date, count)

      :year ->
        add_years(date, count)
    end
  end

  defp add_months(date, months) do
    new_month = date.month + months

    {years_to_add, final_month} =
      if new_month > 12 do
        {div(new_month - 1, 12), rem(new_month - 1, 12) + 1}
      else
        {0, new_month}
      end

    new_year = date.year + years_to_add

    # Handle day overflow (e.g., Jan 31 + 1 month)
    max_day = Date.days_in_month(Date.new!(new_year, final_month, 1))
    final_day = min(date.day, max_day)

    Date.new!(new_year, final_month, final_day)
  end

  defp add_years(date, years) do
    new_year = date.year + years

    # Handle leap year edge case (Feb 29 -> Feb 28)
    final_day =
      if date.month == 2 and date.day == 29 and not Date.leap_year?(Date.new!(new_year, 1, 1)) do
        28
      else
        date.day
      end

    Date.new!(new_year, date.month, final_day)
  end

  defp find_next_occurrence_after(original_date, repeater, reference_date) do
    if Date.compare(original_date, reference_date) != :lt do
      original_date
    else
      # Calculate how many intervals we need to advance
      days_diff = Date.diff(reference_date, original_date)
      interval_days = repeater_interval_days(repeater)

      if interval_days > 0 do
        intervals_needed = div(days_diff, interval_days) + 1
        advance_by_intervals(original_date, repeater, intervals_needed)
      else
        # For hourly repeaters, just return the next day
        Date.add(reference_date, 1)
      end
    end
  end

  defp find_next_occurrence_on_or_after(original_date, repeater, reference_date) do
    cond do
      Date.compare(original_date, reference_date) != :lt ->
        original_date

      repeater_interval_days(repeater) == 0 ->
        # For hourly repeaters, just return the reference date
        reference_date

      true ->
        calculate_next_occurrence_with_intervals(original_date, repeater, reference_date)
    end
  end

  defp calculate_next_occurrence_with_intervals(original_date, repeater, reference_date) do
    days_diff = Date.diff(reference_date, original_date)
    interval_days = repeater_interval_days(repeater)
    intervals_needed = div(days_diff, interval_days)
    candidate = advance_by_intervals(original_date, repeater, intervals_needed)

    if Date.compare(candidate, reference_date) == :lt do
      advance_by_intervals(original_date, repeater, intervals_needed + 1)
    else
      candidate
    end
  end

  defp advance_by_intervals(date, repeater, intervals) do
    %{count: count, unit: unit} = repeater
    multiplied_repeater = %{count: count * intervals, unit: unit}
    add_repeater_interval(date, multiplied_repeater)
  end

  defp generate_occurrences(timestamp, current_date, end_date, repeater, acc) do
    if Date.compare(current_date, end_date) == :gt do
      Enum.reverse(acc)
    else
      current_occurrence = %{
        timestamp
        | date: current_date,
          day_name: day_name_from_date(current_date),
          raw: update_raw_date(timestamp.raw, current_date, day_name_from_date(current_date))
      }

      next_date = add_repeater_interval(current_date, repeater)
      generate_occurrences(timestamp, next_date, end_date, repeater, [current_occurrence | acc])
    end
  end

  defp day_name_from_date(date) do
    case Date.day_of_week(date) do
      1 -> "Mon"
      2 -> "Tue"
      3 -> "Wed"
      4 -> "Thu"
      5 -> "Fri"
      6 -> "Sat"
      7 -> "Sun"
    end
  end

  defp update_raw_date(raw, new_date, new_day_name) do
    # Simple replacement - extract the date pattern and replace it
    date_str = Date.to_string(new_date)

    # Replace the date and day name in the raw string
    raw
    |> String.replace(~r/\d{4}-\d{2}-\d{2}/, date_str)
    |> String.replace(~r/\b(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\b/, new_day_name)
  end
end
