#!/usr/bin/env elixir

# Position Tracking Example
# Demonstrates precise position tracking and fragment management

IO.puts("📍 Fragment Parsing - Position Tracking")
IO.puts("=" |> String.duplicate(45))

# Sample document with known structure
sample_text = """
* Introduction
This is the introduction paragraph.

** Background
Some background information here.
- Point one
- Point two with more detail
- Point three

** Implementation
| Component | Status | Notes |
|-----------|--------|-------|
| Parser | Done | Working well |
| Writer | In Progress | Almost ready |

#+BEGIN_SRC elixir
def hello_world do
  IO.puts("Hello, World!")
end
#+END_SRC
"""

IO.puts("📄 Sample Document:")
IO.puts("-" |> String.duplicate(30))
IO.puts(sample_text)

# Create fragment tracker to analyze positions
IO.puts("\n🔍 Creating Fragment Tracker:")
IO.puts("-" |> String.duplicate(40))

tracker = Org.FragmentTracker.new(sample_text)
IO.puts("Tracked fragments: #{map_size(tracker.fragments)}")
IO.puts("Position index entries: #{map_size(tracker.position_index)}")
IO.puts("Range index entries: #{length(tracker.range_index)}")

# Show position information for each fragment
IO.puts("\n📊 Fragment Position Analysis:")
IO.puts("-" |> String.duplicate(40))

tracker.range_index
|> Enum.sort(fn {{line1, col1}, _}, {{line2, col2}, _} ->
  if line1 == line2, do: col1 <= col2, else: line1 < line2
end)
|> Enum.with_index()
|> Enum.each(fn {{range, fragment_id}, index} ->
  fragment = tracker.fragments[fragment_id]
  {{start_line, start_col}, {end_line, end_col}} = range

  IO.puts("#{index + 1}. #{fragment_id}")
  IO.puts("   Type: #{fragment.fragment.type}")
  IO.puts("   Range: Line #{start_line}, Col #{start_col} → Line #{end_line}, Col #{end_col}")
  IO.puts("   Size: #{end_line - start_line + 1} lines, #{end_col - start_col + 1} chars")

  # Show content preview
  content_preview =
    case fragment.fragment.type do
      :section ->
        "\"#{fragment.fragment.content.title}\""

      :content when is_struct(fragment.fragment.content, Org.Paragraph) ->
        first_line = Enum.at(fragment.fragment.content.lines, 0, "")
        "\"#{String.slice(first_line, 0, 30)}#{if String.length(first_line) > 30, do: "...", else: ""}\""

      :content when is_struct(fragment.fragment.content, Org.List) ->
        "List with #{length(fragment.fragment.content.items)} items"

      :content when is_struct(fragment.fragment.content, Org.Table) ->
        "Table with #{length(fragment.fragment.content.rows)} rows"

      :content when is_struct(fragment.fragment.content, Org.CodeBlock) ->
        "Code block (#{fragment.fragment.content.lang})"

      :line ->
        "\"#{String.slice(fragment.fragment.content, 0, 30)}\""

      _ ->
        "Unknown content"
    end

  IO.puts("   Content: #{content_preview}")
  IO.puts("")
end)

# Demonstrate position-based queries
IO.puts("\n🎯 Position-Based Queries:")
IO.puts("-" |> String.duplicate(40))

test_positions = [
  # Start of document
  {1, 1},
  # Middle of introduction paragraph
  {3, 10},
  # Start of Background section
  {5, 1},
  # In a list item
  {7, 3},
  # Start of Implementation section
  {11, 1},
  # In code block
  {18, 5},
  # Beyond document end
  {25, 1}
]

Enum.each(test_positions, fn position ->
  {line, col} = position
  IO.puts("Position (#{line}, #{col}):")

  fragment = Org.FragmentTracker.find_fragment_at_position(tracker, position)

  if fragment do
    IO.puts("  Found: #{fragment.id} (#{fragment.fragment.type})")
    {{start_line, start_col}, {end_line, end_col}} = fragment.fragment.range
    IO.puts("  Fragment range: (#{start_line}, #{start_col}) to (#{end_line}, #{end_col})")
  else
    IO.puts("  No fragment found at this position")
  end
end)

# Demonstrate range-based queries
IO.puts("\n📏 Range-Based Queries:")
IO.puts("-" |> String.duplicate(40))

query_ranges = [
  # Covers intro and background start
  {{1, 1}, {5, 10}},
  # Covers list items
  {{7, 1}, {10, 20}},
  # Covers table
  {{11, 1}, {15, 30}},
  # Covers code block
  {{16, 1}, {20, 10}},
  # Beyond document
  {{100, 1}, {200, 1}}
]

Enum.each(query_ranges, fn query_range ->
  {{start_line, start_col}, {end_line, end_col}} = query_range
  IO.puts("Range (#{start_line}, #{start_col}) to (#{end_line}, #{end_col}):")

  overlapping = Org.FragmentTracker.find_fragments_in_range(tracker, query_range)

  if length(overlapping) > 0 do
    IO.puts("  Found #{length(overlapping)} overlapping fragments:")

    Enum.each(overlapping, fn frag ->
      IO.puts("    - #{frag.id} (#{frag.fragment.type})")
    end)
  else
    IO.puts("  No fragments overlap with this range")
  end
end)

# Demonstrate fragment updates and position recalculation
IO.puts("\n🔧 Fragment Updates and Position Tracking:")
IO.puts("-" |> String.duplicate(50))

# Get the first fragment and update it
[first_id | _] = Map.keys(tracker.fragments)
original_fragment = tracker.fragments[first_id]

IO.puts("Original fragment #{first_id}:")
IO.puts("  Range: #{inspect(original_fragment.fragment.range)}")
IO.puts("  Content: #{Org.render_fragment(original_fragment.fragment)}")

# Update with different length text
new_text = "* Extended Introduction Section With Much Longer Title"
updated_tracker = Org.FragmentTracker.update_fragment(tracker, first_id, new_text)

updated_fragment = updated_tracker.fragments[first_id]
IO.puts("\nUpdated fragment #{first_id}:")
IO.puts("  Range: #{inspect(updated_fragment.fragment.range)}")
IO.puts("  Content: #{Org.render_fragment(updated_fragment.fragment)}")
IO.puts("  Dirty: #{updated_fragment.dirty}")

# Check if position indexes were updated
range_changed = original_fragment.fragment.range != updated_fragment.fragment.range
IO.puts("  Range changed: #{range_changed}")

if range_changed do
  IO.puts("  Position indexes automatically updated")
end

# Demonstrate insertion and removal
IO.puts("\n➕ Fragment Insertion:")
IO.puts("-" |> String.duplicate(30))

new_position = {25, 1}
insert_text = "* New Section Added Dynamically"

tracker_with_insert = Org.FragmentTracker.insert_fragment(tracker, new_position, insert_text)
IO.puts("Inserted fragment at #{inspect(new_position)}")
IO.puts("Fragment count: #{map_size(tracker.fragments)} → #{map_size(tracker_with_insert.fragments)}")

# Find the newly inserted fragment
new_fragment = Org.FragmentTracker.find_fragment_at_position(tracker_with_insert, new_position)

if new_fragment do
  IO.puts("New fragment ID: #{new_fragment.id}")
  IO.puts("New fragment dirty: #{new_fragment.dirty}")
end

IO.puts("\n➖ Fragment Removal:")
IO.puts("-" |> String.duplicate(30))

# Remove a fragment
[remove_id | _] = Map.keys(tracker.fragments)
tracker_after_removal = Org.FragmentTracker.remove_fragment(tracker, remove_id)

IO.puts("Removed fragment: #{remove_id}")
IO.puts("Fragment count: #{map_size(tracker.fragments)} → #{map_size(tracker_after_removal.fragments)}")

# Verify it's gone
removed_check = Map.get(tracker_after_removal.fragments, remove_id)
IO.puts("Fragment still exists: #{removed_check != nil}")

# Show source regeneration
IO.puts("\n🔄 Source Text Regeneration:")
IO.puts("-" |> String.duplicate(40))

IO.puts("Original lines: #{String.split(sample_text, "\n") |> length()}")

regenerated = Org.FragmentTracker.regenerate_source(tracker)
IO.puts("Regenerated lines: #{String.split(regenerated, "\n") |> length()}")

# Show similarity
original_words = String.split(sample_text) |> length()
regenerated_words = String.split(regenerated) |> length()
IO.puts("Word count similarity: #{original_words} → #{regenerated_words}")

# Clean up dirty fragments
IO.puts("\n🧹 Fragment State Management:")
IO.puts("-" |> String.duplicate(40))

dirty_fragments = Org.FragmentTracker.get_dirty_fragments(updated_tracker)
IO.puts("Dirty fragments: #{length(dirty_fragments)}")

if length(dirty_fragments) > 0 do
  [dirty_id | _] = Enum.map(dirty_fragments, & &1.id)
  clean_tracker = Org.FragmentTracker.mark_fragment_clean(updated_tracker, dirty_id)

  remaining_dirty = Org.FragmentTracker.get_dirty_fragments(clean_tracker)
  IO.puts("After cleaning one: #{length(remaining_dirty)} dirty fragments remain")
end

IO.puts("\n✅ Position tracking examples completed!")
IO.puts("🎯 Key features demonstrated:")
IO.puts("  - Precise position tracking (line, column)")
IO.puts("  - Range-based fragment queries")
IO.puts("  - Position updates during edits")
IO.puts("  - Fragment insertion and removal")
IO.puts("  - Source text regeneration")
IO.puts("  - Dirty state management")
