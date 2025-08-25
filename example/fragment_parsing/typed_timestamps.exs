#!/usr/bin/env elixir

# Add the lib directory to the code path
Code.prepend_path("../../lib")

# Start the OTP application to make modules available
Application.ensure_all_started(:org)

# Example demonstrating typed timestamp support
IO.puts("=== Org-mode Typed Timestamps Example ===\n")

alias Org.{FragmentParser, Timestamp}

# Example 1: Basic timestamp parsing
IO.puts("1. Basic Timestamp Parsing:")

basic_text = """
* Meeting
  SCHEDULED: <2024-01-15 Mon 14:30>
"""

fragment1 = FragmentParser.parse_fragment(basic_text)
scheduled = fragment1.content.metadata.scheduled

IO.puts("   Original timestamp: SCHEDULED: <2024-01-15 Mon 14:30>")
IO.puts("   Parsed as: #{inspect(scheduled.__struct__)}")
IO.puts("   Type: #{scheduled.type} (#{if Timestamp.active?(scheduled), do: "shows in agenda", else: "hidden"})")
IO.puts("   Date: #{scheduled.date}")
IO.puts("   Time: #{if scheduled.start_time, do: scheduled.start_time, else: "no time specified"}")
IO.puts("   Day name: #{scheduled.day_name}")
IO.puts("")

# Example 2: Time ranges
IO.puts("2. Time Ranges:")

range_text = """
* Conference Call
  SCHEDULED: <2024-01-15 Mon 14:30-16:00>
"""

fragment2 = FragmentParser.parse_fragment(range_text)
scheduled_range = fragment2.content.metadata.scheduled

IO.puts("   Original: SCHEDULED: <2024-01-15 Mon 14:30-16:00>")
IO.puts("   Has time range: #{Timestamp.time_range?(scheduled_range)}")
IO.puts("   Start time: #{scheduled_range.start_time}")
IO.puts("   End time: #{scheduled_range.end_time}")
IO.puts("   Duration: #{Time.diff(scheduled_range.end_time, scheduled_range.start_time)} seconds")

# Convert to DateTime for easier manipulation
start_dt = Timestamp.to_datetime(scheduled_range)
end_dt = Timestamp.end_datetime(scheduled_range)
IO.puts("   Start DateTime: #{start_dt}")
IO.puts("   End DateTime: #{end_dt}")
IO.puts("")

# Example 3: Repeaters and warnings
IO.puts("3. Repeaters and Warnings:")

repeat_text = """
* Weekly Team Meeting
  SCHEDULED: <2024-01-15 Mon 10:00 +1w -2d>
"""

fragment3 = FragmentParser.parse_fragment(repeat_text)
repeating = fragment3.content.metadata.scheduled

IO.puts("   Original: SCHEDULED: <2024-01-15 Mon 10:00 +1w -2d>")
IO.puts("   Repeating: #{Timestamp.repeating?(repeating)}")
IO.puts("   Repeater: every #{repeating.repeater.count} #{repeating.repeater.unit}(s)")
IO.puts("   Warning: #{repeating.warning.count} #{repeating.warning.unit}(s) before")
IO.puts("")

# Example 4: Multiple timestamp types
IO.puts("4. Multiple Timestamp Types:")

multi_text = """
** DONE [#A] Project Milestone :work:important:
   SCHEDULED: <2024-01-10 Wed 09:00>
   DEADLINE: <2024-01-15 Mon 17:00 -1d>
   CLOSED: [2024-01-14 Sun 20:30]
"""

fragment4 = FragmentParser.parse_fragment(multi_text)
metadata = fragment4.content.metadata

IO.puts("   Task: #{fragment4.content.title}")
IO.puts("   Status: #{fragment4.content.todo_keyword}")
IO.puts("")

IO.puts("   SCHEDULED (active): #{Timestamp.to_string(metadata.scheduled)}")
IO.puts("     - Type: #{metadata.scheduled.type}")
IO.puts("     - Date: #{metadata.scheduled.date}")
IO.puts("     - Time: #{metadata.scheduled.start_time}")

IO.puts("   DEADLINE (active): #{Timestamp.to_string(metadata.deadline)}")
IO.puts("     - Type: #{metadata.deadline.type}")
IO.puts("     - Warning: #{metadata.deadline.warning.count} #{metadata.deadline.warning.unit} before")
IO.puts("     - DateTime: #{Timestamp.to_datetime(metadata.deadline)}")

IO.puts("   CLOSED (inactive): #{Timestamp.to_string(metadata.closed)}")
IO.puts("     - Type: #{metadata.closed.type}")
IO.puts("     - Completed at: #{Timestamp.to_datetime(metadata.closed)}")
IO.puts("")

# Example 5: DateTime operations
IO.puts("5. DateTime Operations:")

# Calculate time until deadline
deadline_dt = Timestamp.to_datetime(metadata.deadline)
now = DateTime.utc_now()
time_diff = DateTime.diff(deadline_dt, now, :day)

IO.puts("   Deadline: #{deadline_dt}")
IO.puts("   Current time: #{now}")

if time_diff > 0 do
  IO.puts("   Time until deadline: #{time_diff} days")
else
  IO.puts("   Deadline was #{abs(time_diff)} days ago")
end

# Calculate task duration (scheduled to closed)
scheduled_dt = Timestamp.to_datetime(metadata.scheduled)
closed_dt = Timestamp.to_datetime(metadata.closed)
duration_hours = DateTime.diff(closed_dt, scheduled_dt, :hour)
IO.puts("   Task duration: #{duration_hours} hours")
IO.puts("")

# Example 6: Different timestamp formats
IO.puts("6. Different Timestamp Formats:")

formats = [
  # Date only
  "<2024-01-15>",
  # Date with day
  "<2024-01-15 Mon>",
  # Date, day, time
  "<2024-01-15 Mon 14:30>",
  # Time range
  "<2024-01-15 Mon 14:30-16:00>",
  # Inactive timestamp
  "[2024-01-15 Mon 14:30]",
  # With repeater
  "<2024-01-15 Mon +1w>",
  # With warning
  "<2024-01-15 Mon 14:30 -2h>",
  # Full format
  "<2024-01-15 Mon 14:30 +1w -2h>",
  # Daily repeat
  "<2024-01-15 Mon +1d>",
  # Monthly repeat
  "<2024-01-15 Mon +1m>",
  # Yearly repeat
  "<2024-01-15 Mon +1y>"
]

for format <- formats do
  case Timestamp.parse(format) do
    {:ok, ts} ->
      features = []
      features = if Timestamp.has_time?(ts), do: ["time" | features], else: features
      features = if Timestamp.time_range?(ts), do: ["range" | features], else: features
      features = if Timestamp.repeating?(ts), do: ["repeat" | features], else: features
      features = if ts.warning, do: ["warning" | features], else: features
      features = if Timestamp.active?(ts), do: features, else: ["inactive" | features]

      feature_str = if Enum.empty?(features), do: "date-only", else: Enum.join(features, ", ")
      IO.puts("   #{format} → #{feature_str}")

    {:error, reason} ->
      IO.puts("   #{format} → ERROR: #{reason}")
  end
end

IO.puts("")

# Example 7: Working with the parsed data
IO.puts("7. Working with Parsed Timestamp Data:")

all_tasks_text = """
* TODO Morning Standup
  SCHEDULED: <2024-01-15 Mon 09:00>
* TODO Code Review  
  SCHEDULED: <2024-01-15 Mon 14:00-16:00>
* TODO Weekly Planning
  SCHEDULED: <2024-01-15 Mon 16:30 +1w>
"""

fragments = FragmentParser.parse_fragments(all_tasks_text)

scheduled_tasks =
  fragments
  |> Enum.filter(fn f -> f.type == :section and Map.has_key?(f.content.metadata, :scheduled) end)
  |> Enum.sort_by(fn f -> Timestamp.to_datetime(f.content.metadata.scheduled) end)

IO.puts("   Today's scheduled tasks (sorted by time):")

for task <- scheduled_tasks do
  timestamp = task.content.metadata.scheduled
  time_str = if timestamp.start_time, do: Time.to_string(timestamp.start_time), else: "no time"

  features = []

  features =
    if Timestamp.time_range?(timestamp),
      do: ["#{timestamp.start_time}-#{timestamp.end_time}" | features],
      else: features

  features = if Timestamp.repeating?(timestamp), do: ["repeats" | features], else: features

  feature_str = if Enum.empty?(features), do: "", else: " (#{Enum.join(features, ", ")})"

  IO.puts("     #{time_str}: #{task.content.title}#{feature_str}")
end

IO.puts("")

# Example 8: JSON serialization
IO.puts("8. JSON Serialization:")

json_fragment =
  FragmentParser.parse_fragment("""
  * Meeting
    SCHEDULED: <2024-01-15 Mon 14:30-16:00 +1w>
  """)

json_data = Org.JSONEncoder.encode(json_fragment.content)
scheduled_json = json_data.metadata.scheduled

IO.puts("   Timestamp serialized to JSON:")
IO.puts("   Type: #{scheduled_json.type}")
IO.puts("   Timestamp type: #{scheduled_json.timestamp_type}")
IO.puts("   Date: #{scheduled_json.date}")
IO.puts("   Start time: #{scheduled_json.start_time}")
IO.puts("   End time: #{scheduled_json.end_time}")
IO.puts("   Repeater: #{inspect(scheduled_json.repeater)}")
IO.puts("   Original raw: #{scheduled_json.raw}")
IO.puts("")

# Example 9: Round-trip conversion
IO.puts("9. Round-trip Conversion:")
original_ts_str = "<2024-01-15 Mon 14:30-16:00 +1w -2d>"
{:ok, parsed_ts} = Timestamp.parse(original_ts_str)
rendered_ts_str = Timestamp.to_string(parsed_ts)

IO.puts("   Original:  #{original_ts_str}")
IO.puts("   Parsed:    #{inspect(parsed_ts.date)} #{inspect(parsed_ts.start_time)}-#{inspect(parsed_ts.end_time)}")
IO.puts("   Rendered:  #{rendered_ts_str}")
IO.puts("   Match:     #{original_ts_str == rendered_ts_str}")
IO.puts("")

IO.puts("=== Typed Timestamps Support Complete! ===")
IO.puts("")
IO.puts("Key Benefits:")
IO.puts("- Parse org-mode timestamps into proper Elixir Date/DateTime types")
IO.puts("- Easy manipulation with built-in Elixir date/time functions")
IO.puts("- Type safety and better validation")
IO.puts("- Rich query and filtering capabilities")
IO.puts("- JSON serialization with full type information")
IO.puts("- Perfect round-trip parsing (parse → manipulate → render)")
