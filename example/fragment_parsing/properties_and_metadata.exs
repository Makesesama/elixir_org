#!/usr/bin/env elixir

# Add the lib directory to the code path
Code.prepend_path("../../lib")

# Start the OTP application to make modules available
Application.ensure_all_started(:org)

# Example demonstrating property drawers and metadata support
IO.puts("=== Org-mode Properties and Metadata Example ===\n")

alias Org.FragmentParser

# Example 1: Section with properties only
IO.puts("1. Section with Properties:")

properties_text = """
* Project Management Task
  :PROPERTIES:
  :ID: proj-001
  :Assigned: John Smith
  :Priority: High
  :Effort: 5d
  :URL: https://project.example.com/task/001
  :END:
"""

fragment1 = FragmentParser.parse_fragment(properties_text)
IO.puts("   Title: #{inspect(fragment1.content.title)}")
IO.puts("   Properties:")

Enum.each(fragment1.content.properties, fn {key, value} ->
  IO.puts("     #{key}: #{value}")
end)

IO.puts("")

# Example 2: Section with metadata only
IO.puts("2. Section with Metadata:")

metadata_text = """
* TODO Important Meeting
  SCHEDULED: <2024-01-15 Mon 14:00>
  DEADLINE: <2024-01-15 Mon 16:00>
"""

fragment2 = FragmentParser.parse_fragment(metadata_text)
IO.puts("   Title: #{fragment2.content.title}")
IO.puts("   TODO: #{fragment2.content.todo_keyword}")
IO.puts("   Metadata:")

Enum.each(fragment2.content.metadata, fn {key, value} ->
  IO.puts("     #{String.upcase(to_string(key))}: #{value}")
end)

IO.puts("")

# Example 3: Section with both properties and metadata
IO.puts("3. Section with Both Properties and Metadata:")

complex_text = """
** DONE [#A] Sprint Planning Meeting :work:meeting:
   :PROPERTIES:
   :MEETING_ID: sprint-2024-01
   :LOCATION: Conference Room A
   :ATTENDEES: 8
   :DURATION: 2h
   :NOTES: https://notes.example.com/sprint-planning
   :END:
   SCHEDULED: <2024-01-10 Wed 09:00>
   DEADLINE: <2024-01-10 Wed 11:00>
   CLOSED: [2024-01-10 Wed 10:45]
"""

fragment3 = FragmentParser.parse_fragment(complex_text)
IO.puts("   Title: #{fragment3.content.title}")
IO.puts("   TODO: #{fragment3.content.todo_keyword}")
IO.puts("   Priority: #{fragment3.content.priority}")
IO.puts("   Tags: #{inspect(fragment3.content.tags)}")
IO.puts("   Properties:")

Enum.each(fragment3.content.properties, fn {key, value} ->
  IO.puts("     #{key}: #{value}")
end)

IO.puts("   Metadata:")

Enum.each(fragment3.content.metadata, fn {key, value} ->
  IO.puts("     #{String.upcase(to_string(key))}: #{value}")
end)

IO.puts("")

# Example 4: Rendering back to org-mode format
IO.puts("4. Round-trip: Parse and Render:")

original = """
* Development Task :dev:
  :PROPERTIES:
  :CUSTOM_ID: dev-task-001
  :CATEGORY: Development
  :END:
  SCHEDULED: <2024-02-01 Thu>
"""

parsed = FragmentParser.parse_fragment(original)
rendered = FragmentParser.render_fragment(parsed)

IO.puts("   Original:")
IO.puts("#{String.trim(original) |> String.replace("\n", "\n   ")}")
IO.puts("")
IO.puts("   Rendered:")
IO.puts("#{rendered |> String.replace("\n", "\n   ")}")
IO.puts("")

# Example 5: Properties with special characters and values
IO.puts("5. Properties with Special Characters:")

special_text = """
* Web Development Project
  :PROPERTIES:
  :URL: https://example.com:8080/api/v1?token=abc123
  :Description: A project with "quotes" and special chars!
  :Email: developer@company.com
  :Tags: frontend,backend,api
  :Started:
  :Completed: 
  :END:
"""

fragment5 = FragmentParser.parse_fragment(special_text)
IO.puts("   Title: #{fragment5.content.title}")
IO.puts("   Properties with special handling:")

Enum.each(fragment5.content.properties, fn {key, value} ->
  display_value = if String.length(value) == 0, do: "(empty)", else: value
  IO.puts("     #{key}: #{display_value}")
end)

IO.puts("")

# Example 6: Metadata with time specifications and warnings
IO.puts("6. Advanced Metadata with Times and Warnings:")

advanced_metadata = """
* Client Presentation
  SCHEDULED: <2024-03-15 Fri 14:00-16:00>
  DEADLINE: <2024-03-15 Fri 16:00 -2h>
"""

fragment6 = FragmentParser.parse_fragment(advanced_metadata)
IO.puts("   Title: #{fragment6.content.title}")
IO.puts("   Advanced metadata:")

Enum.each(fragment6.content.metadata, fn {key, value} ->
  IO.puts("     #{String.upcase(to_string(key))}: #{value}")
end)

IO.puts("")

# Example 7: Using with custom keywords
IO.puts("7. Properties and Metadata with Custom Keywords:")

custom_config =
  FragmentParser.custom_keyword_config([
    FragmentParser.workflow_sequence(["PROPOSAL", "APPROVED", "INWORK"], ["COMPLETED", "REJECTED"])
  ])

custom_text = """
* INWORK Feature Implementation
  :PROPERTIES:
  :FEATURE_ID: feat-2024-001
  :REQUESTOR: Product Team
  :COMPLEXITY: High
  :ESTIMATE: 10d
  :END:
  SCHEDULED: <2024-02-15 Thu>
  DEADLINE: <2024-02-25 Sun>
"""

fragment7 = FragmentParser.parse_fragment(custom_text, keyword_config: custom_config)
IO.puts("   Title: #{fragment7.content.title}")
IO.puts("   Custom Keyword: #{fragment7.content.todo_keyword}")
IO.puts("   Properties:")

Enum.each(fragment7.content.properties, fn {key, value} ->
  IO.puts("     #{key}: #{value}")
end)

IO.puts("   Metadata:")

Enum.each(fragment7.content.metadata, fn {key, value} ->
  IO.puts("     #{String.upcase(to_string(key))}: #{value}")
end)

IO.puts("")

# Example 8: Working with the PropertyDrawer module directly
IO.puts("8. Direct PropertyDrawer Usage:")

lines = [
  ":PROPERTIES:",
  ":PRIORITY: High",
  ":OWNER: Alice",
  ":END:",
  "SCHEDULED: <2024-01-20 Sat>",
  "Regular content follows"
]

{properties, metadata, remaining} = Org.PropertyDrawer.extract_all(lines)
IO.puts("   Extracted properties: #{inspect(properties)}")
IO.puts("   Extracted metadata: #{inspect(metadata)}")
IO.puts("   Remaining content: #{inspect(remaining)}")
IO.puts("")

# Example 9: JSON encoding with properties and metadata
IO.puts("9. JSON Encoding:")

json_fragment =
  FragmentParser.parse_fragment("""
  * Data Analysis Task
    :PROPERTIES:
    :DATASET: sales-2024-q1.csv
    :METHOD: linear-regression
    :END:
    SCHEDULED: <2024-01-30 Tue>
  """)

encoded = Org.JSONEncoder.encode(json_fragment.content)
IO.puts("   JSON structure keys: #{inspect(Map.keys(encoded))}")
IO.puts("   Properties in JSON: #{inspect(encoded.properties)}")
IO.puts("   Metadata in JSON: #{inspect(encoded.metadata)}")
IO.puts("")

IO.puts("=== Properties and Metadata Support Complete! ===")
