#!/usr/bin/env elixir

# Incremental Editing Example
# Demonstrates how to use the incremental parser for efficient document editing

IO.puts("🔄 Fragment Parsing - Incremental Editing")
IO.puts("=" |> String.duplicate(45))

# Start with a sample document
initial_text = """
* Project Planning
We need to plan the project carefully.

** Research Phase
- Literature review
- Market analysis
- Competitor study

** Development Phase  
- Architecture design
- Implementation
- Testing

* Budget Considerations
Initial budget: $10,000
"""

IO.puts("📄 Initial Document:")
IO.puts("-" |> String.duplicate(30))
IO.puts(initial_text)

# Create incremental parser state
IO.puts("\n🔧 Setting up incremental parser...")
state = Org.new_incremental_parser(initial_text)

IO.puts("Initial version: #{Org.IncrementalParser.get_version(state)}")
IO.puts("Document sections: #{length(state.document.sections)}")
IO.puts("Fragment tracker has #{map_size(state.tracker.fragments)} fragments")

# Simulate editing scenario 1: Change a section title
IO.puts("\n📝 Edit 1: Changing section title")
IO.puts("-" |> String.duplicate(40))

change1 = %{
  # "Project Planning"
  range: {{1, 3}, {1, 18}},
  old_text: "Project Planning",
  new_text: "Project Management"
}

IO.puts("Change: #{inspect(change1)}")

state = Org.apply_incremental_change(state, change1)
IO.puts("Pending changes: #{Org.has_pending_incremental_changes?(state)}")

# Preview what would change
preview = Org.IncrementalParser.preview_changes(state)
IO.puts("Affected fragments: #{length(preview.affected_fragments)}")
IO.puts("Affected sections: #{length(preview.affected_sections)}")

# Commit the change
state = Org.commit_incremental_changes(state)
IO.puts("Version after commit: #{Org.IncrementalParser.get_version(state)}")

# Simulate editing scenario 2: Add new list item
IO.puts("\n📝 Edit 2: Adding new list item")
IO.puts("-" |> String.duplicate(40))

change2 = %{
  # End of "Competitor study"
  range: {{7, 18}, {7, 18}},
  old_text: "",
  new_text: "\n- Technology assessment"
}

IO.puts("Change: #{inspect(change2)}")

state = Org.apply_incremental_change(state, change2)

# Simulate editing scenario 3: Update budget information
IO.puts("\n📝 Edit 3: Updating budget")
IO.puts("-" |> String.duplicate(40))

change3 = %{
  # "$10,000"
  range: {{16, 17}, {16, 24}},
  old_text: "$10,000",
  new_text: "$15,000"
}

IO.puts("Change: #{inspect(change3)}")

state = Org.apply_incremental_change(state, change3)

# Show pending changes before commit
IO.puts("\n📋 Before final commit:")
preview = Org.IncrementalParser.preview_changes(state)
IO.puts("Pending changes: #{length(state.pending_changes)}")
IO.puts("Will affect #{length(preview.affected_fragments)} fragments")

# Commit all pending changes
state = Org.commit_incremental_changes(state)
IO.puts("\n✅ All changes committed")
IO.puts("Final version: #{Org.IncrementalParser.get_version(state)}")

# Show the final result by regenerating source text
IO.puts("\n📄 Final Document:")
IO.puts("-" |> String.duplicate(30))

final_text = Org.FragmentTracker.regenerate_source(state.tracker)
IO.puts(final_text)

# Demonstrate fragment-level updates
IO.puts("\n🧩 Fragment-Level Updates:")
IO.puts("-" |> String.duplicate(40))

# Create a standalone fragment and update it
fragment = Org.parse_fragment("* TODO [#C] Low priority task")
IO.puts("Original fragment: #{Org.render_fragment(fragment)}")

updated_fragment = Org.update_fragment(fragment, "* DONE [#A] High priority task")
IO.puts("Updated fragment: #{Org.render_fragment(updated_fragment)}")

IO.puts("Position preserved: #{fragment.range == updated_fragment.range}")

# Demonstrate error handling with malformed input
IO.puts("\n🛡️ Handling Partial Input:")
IO.puts("-" |> String.duplicate(40))

partial_inputs = [
  "* tod hello",
  "- test1\n- test2\n-",
  "*    wassup",
  "| incomplete table",
  # No END_SRC
  "#+BEGIN_SRC python\nprint('hello')"
]

Enum.each(partial_inputs, fn input ->
  fragment = Org.parse_fragment(input)
  IO.puts("Input: #{inspect(input)}")
  IO.puts("  -> Type: #{fragment.type}, Content present: #{fragment.content != nil}")

  # Show it can be rendered back
  rendered = Org.render_fragment(fragment)
  IO.puts("  -> Rendered: #{inspect(rendered)}")
end)

# Performance comparison simulation
IO.puts("\n⚡ Performance Benefits:")
IO.puts("-" |> String.duplicate(40))

large_doc = String.duplicate("* Section #{:rand.uniform(1000)}\nContent line\n\n", 100)
IO.puts("Testing with document of #{String.split(large_doc, "\n") |> length()} lines")

# Time full parsing
{time_full, _} =
  :timer.tc(fn ->
    Enum.each(1..10, fn _ -> Org.Parser.parse(large_doc) end)
  end)

# Time incremental setup + small change
{time_incremental, _} =
  :timer.tc(fn ->
    state = Org.new_incremental_parser(large_doc)

    change = %{
      range: {{1, 3}, {1, 10}},
      old_text: "Section",
      new_text: "Modified"
    }

    state
    |> Org.apply_incremental_change(change)
    |> Org.commit_incremental_changes()
  end)

IO.puts("Full parsing (10x): #{time_full / 1000} ms")
IO.puts("Incremental (setup + change): #{time_incremental / 1000} ms")
IO.puts("Speedup potential: #{Float.round(time_full / time_incremental, 2)}x")

IO.puts("\n✅ Incremental editing examples completed!")
IO.puts("🎯 Key benefits demonstrated:")
IO.puts("  - Efficient partial updates")
IO.puts("  - Position tracking preservation")
IO.puts("  - Robust error handling")
IO.puts("  - Performance optimization for large documents")
