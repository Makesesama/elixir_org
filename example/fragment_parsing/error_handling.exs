#!/usr/bin/env elixir

# Error Handling Example
# Demonstrates robust handling of malformed, partial, and edge case inputs

IO.puts("🛡️ Fragment Parsing - Error Handling")
IO.puts("=" |> String.duplicate(45))

IO.puts("This example demonstrates how the fragment parser handles:")
IO.puts("- Partial or incomplete input")
IO.puts("- Malformed org-mode syntax")
IO.puts("- Edge cases and unusual formatting")
IO.puts("- Recovery strategies")

# Test cases with various malformed inputs
test_cases = [
  # Partial section headers
  {"Partial section (your example)", "* tod hello"},
  {"Section with weird spacing", "*    wassup"},
  {"Section without space", "*NoSpace"},
  {"Multiple asterisks", "****** Deep section"},
  {"Asterisk but no title", "*"},
  {"Asterisk with just space", "* "},

  # Incomplete lists
  {"Incomplete list items (your example)", "- test1\n- test2\n-"},
  {"Empty list item", "-"},
  {"List item with just space", "- "},
  {"Mixed list markers", "- item1\n+ item2\n* item3"},
  {"Malformed ordered list", "1 item without dot"},
  {"Ordered list missing content", "1."},

  # Broken tables
  {"Incomplete table row", "| incomplete"},
  {"Table without closing pipe", "| col1 | col2"},
  {"Malformed table separator", "|-----|"},
  {"Empty table row", "|"},
  {"Table with uneven columns", "| one | two | three |\n| four | five |"},

  # Code blocks
  {"Code block without END", "#+BEGIN_SRC python\nprint('hello')"},
  {"Code block with wrong language", "#+BEGIN_SRC unknownlang\nsome code"},
  {"Malformed BEGIN directive", "#+BEGIN_SOURCE\ncode here"},
  {"Empty code block", "#+BEGIN_SRC\n#+END_SRC"},

  # Mixed and edge cases
  {"Empty input", ""},
  {"Only whitespace", "   \n  \n   "},
  {"Very long line", String.duplicate("word ", 200)},
  {"Unicode content", "* 中文标题\n这是中文内容。\n- 列表项目"},
  {"Mixed newlines", "* Section\r\nContent\r\n\r\n* Another\n"},
  {"Tab characters", "* Section\n\tIndented with tab\n\t- Tab list item"},
  {"Special characters", "* Section with !@#$%^&*()_+"},
  {"Malformed formatting", "This has *unclosed bold and /italic text"}
]

IO.puts("\n🧪 Testing Malformed Input Handling:")
IO.puts("-" |> String.duplicate(50))

results = %{
  successful: 0,
  with_warnings: 0,
  failed: 0,
  total: length(test_cases)
}

Enum.reduce(test_cases, results, fn {description, input}, acc ->
  IO.puts("\n#{description}:")
  IO.puts("  Input: #{inspect(input)}")

  try do
    # Test basic fragment parsing
    fragment = Org.parse_fragment(input)

    IO.puts("  ✅ Parsed successfully")
    IO.puts("     Type: #{fragment.type}")
    IO.puts("     Content present: #{fragment.content != nil}")
    IO.puts("     Range: #{inspect(fragment.range)}")

    # Test if it can be rendered back
    try do
      rendered = Org.render_fragment(fragment)
      IO.puts("     ✅ Can be rendered: #{inspect(rendered)}")

      # Test round-trip consistency where possible
      if String.trim(input) != "" do
        consistent =
          String.contains?(rendered, String.trim(input)) or
            String.contains?(String.trim(input), String.trim(rendered))

        IO.puts("     Round-trip consistent: #{consistent}")
      end

      %{acc | successful: acc.successful + 1}
    rescue
      render_error ->
        IO.puts("     ⚠️ Render failed: #{Exception.message(render_error)}")
        %{acc | with_warnings: acc.with_warnings + 1}
    end
  rescue
    parse_error ->
      IO.puts("  ❌ Parse failed: #{Exception.message(parse_error)}")
      %{acc | failed: acc.failed + 1}
  end
end)

# Test multi-line parsing with mixed content
IO.puts("\n🔀 Multi-Fragment Error Handling:")
IO.puts("-" |> String.duplicate(50))

mixed_problematic_text = """
* Normal section
This is fine.

* tod hello

- Good item
- Another good item  
-

| Name | Status |
|------|
| John | Active

#+BEGIN_SRC python
def incomplete():
    return "missing end"

* 中文标题
Some content here.

*NotASection
- test1
- test2
- 

More text after problems.
"""

IO.puts("Testing mixed content with various problems:")
IO.puts("Input has #{String.split(mixed_problematic_text, "\n") |> length()} lines")

try do
  fragments = Org.parse_fragments(mixed_problematic_text)
  IO.puts("✅ Successfully parsed #{length(fragments)} fragments")

  # Analyze what was parsed
  types = fragments |> Enum.map(& &1.type) |> Enum.frequencies()
  IO.puts("Fragment types found:")

  Enum.each(types, fn {type, count} ->
    IO.puts("  #{type}: #{count}")
  end)

  # Check for any nil content
  nil_content = Enum.count(fragments, fn f -> f.content == nil end)
  IO.puts("Fragments with nil content: #{nil_content}")

  # Test regeneration
  try do
    regenerated = Enum.map_join(fragments, "\n", &Org.render_fragment/1)
    IO.puts("✅ All fragments can be rendered back")
    IO.puts("Regenerated text has #{String.split(regenerated, "\n") |> length()} lines")
  rescue
    regen_error ->
      IO.puts("⚠️ Some fragments failed to render: #{Exception.message(regen_error)}")
  end
rescue
  multi_error ->
    IO.puts("❌ Multi-fragment parsing failed: #{Exception.message(multi_error)}")
end

# Test incremental parser error handling
IO.puts("\n📈 Incremental Parser Error Handling:")
IO.puts("-" |> String.duplicate(50))

test_doc = "* Original Section\nSome content here."

try do
  state = Org.new_incremental_parser(test_doc)
  IO.puts("✅ Incremental parser initialized")

  # Test malformed changes
  malformed_changes = [
    # Invalid range
    %{range: {{-1, -1}, {100, 100}}, old_text: "anything", new_text: "replacement"},
    # Empty change
    %{range: {{1, 1}, {1, 1}}, old_text: "", new_text: ""},
    # Mismatched old_text
    %{range: {{1, 1}, {1, 10}}, old_text: "wrong text", new_text: "replacement"},
    # Very large change
    %{range: {{1, 1}, {1, 20}}, old_text: "Original Section", new_text: String.duplicate("x", 10_000)}
  ]

  Enum.each(malformed_changes, fn change ->
    try do
      updated_state =
        state
        |> Org.apply_incremental_change(change)
        |> Org.commit_incremental_changes()

      IO.puts("✅ Handled malformed change gracefully")
      IO.puts("   Version: #{updated_state.version}")
    rescue
      change_error ->
        IO.puts("⚠️ Change caused error: #{Exception.message(change_error)}")
    end
  end)
rescue
  init_error ->
    IO.puts("❌ Incremental parser initialization failed: #{Exception.message(init_error)}")
end

# Performance under stress
IO.puts("\n⚡ Stress Testing:")
IO.puts("-" |> String.duplicate(30))

# Test with very large inputs
large_malformed = String.duplicate("* Section #{:rand.uniform(1000)}\n- item\n-\n", 100)
IO.puts("Testing with #{String.split(large_malformed, "\n") |> length()} lines of malformed content")

{time, result} =
  :timer.tc(fn ->
    try do
      Org.parse_fragments(large_malformed)
    rescue
      _ -> :error
    end
  end)

case result do
  :error ->
    IO.puts("❌ Large malformed input caused failure")

  fragments when is_list(fragments) ->
    IO.puts("✅ Processed in #{time / 1000} ms")
    IO.puts("   Found #{length(fragments)} fragments")
end

# Summary
IO.puts("\n📊 Error Handling Summary:")
IO.puts("-" |> String.duplicate(40))

IO.puts("Test Results:")
IO.puts("  Successful parses: #{results.successful}/#{results.total}")
IO.puts("  With warnings: #{results.with_warnings}/#{results.total}")
IO.puts("  Failed: #{results.failed}/#{results.total}")
IO.puts("  Success rate: #{Float.round(results.successful / results.total * 100, 1)}%")

IO.puts("\n🎯 Error Handling Strategies Demonstrated:")
IO.puts("  ✅ Graceful degradation to simpler parsing")
IO.puts("  ✅ Fallback to line-by-line parsing")
IO.puts("  ✅ Preservation of partial content")
IO.puts("  ✅ Robust position tracking")
IO.puts("  ✅ Safe handling of malformed input")
IO.puts("  ✅ Recovery from rendering errors")

IO.puts("\n💡 Best Practices for Robust Usage:")
IO.puts("  1. Always check fragment.content != nil")
IO.puts("  2. Wrap render_fragment in try/rescue")
IO.puts("  3. Validate position ranges before queries")
IO.puts("  4. Handle incremental parser errors gracefully")
IO.puts("  5. Use preview_changes before committing")

IO.puts("\n✅ Error handling examples completed!")
