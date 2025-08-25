#!/usr/bin/env elixir

# Add the lib directory to the code path
Code.prepend_path("../../lib")

# Start the OTP application to make modules available
Application.ensure_all_started(:org)

# Example demonstrating tag support in org-mode sections
IO.puts("=== Org-mode Tag Support Example ===\n")

# Example 1: Simple section with single tag
IO.puts("1. Section with single tag:")
text1 = "* Meeting notes :work:"
fragment1 = Org.FragmentParser.parse_fragment(text1)

IO.puts("   Original: #{inspect(text1)}")
IO.puts("   Title: #{inspect(fragment1.content.title)}")
IO.puts("   Tags: #{inspect(fragment1.content.tags)}")
IO.puts("   Rendered: #{inspect(Org.FragmentParser.render_fragment(fragment1))}")
IO.puts("")

# Example 2: Section with multiple tags
IO.puts("2. Section with multiple tags:")
text2 = "** TODO [#A] Project planning :work:urgent:project:"
fragment2 = Org.FragmentParser.parse_fragment(text2)

IO.puts("   Original: #{inspect(text2)}")
IO.puts("   Title: #{inspect(fragment2.content.title)}")
IO.puts("   TODO: #{inspect(fragment2.content.todo_keyword)}")
IO.puts("   Priority: #{inspect(fragment2.content.priority)}")
IO.puts("   Tags: #{inspect(fragment2.content.tags)}")
IO.puts("   Rendered: #{inspect(Org.FragmentParser.render_fragment(fragment2))}")
IO.puts("")

# Example 3: Section without tags
IO.puts("3. Section without tags:")
text3 = "*** DONE Research task"
fragment3 = Org.FragmentParser.parse_fragment(text3)

IO.puts("   Original: #{inspect(text3)}")
IO.puts("   Title: #{inspect(fragment3.content.title)}")
IO.puts("   TODO: #{inspect(fragment3.content.todo_keyword)}")
IO.puts("   Tags: #{inspect(fragment3.content.tags)}")
IO.puts("   Rendered: #{inspect(Org.FragmentParser.render_fragment(fragment3))}")
IO.puts("")

# Example 4: Edge case - colon in title but not tags
IO.puts("4. Edge case - colon in title:")
text4 = "* Meeting at 10:30 AM"
fragment4 = Org.FragmentParser.parse_fragment(text4)

IO.puts("   Original: #{inspect(text4)}")
IO.puts("   Title: #{inspect(fragment4.content.title)}")
IO.puts("   Tags: #{inspect(fragment4.content.tags)}")
IO.puts("   Rendered: #{inspect(Org.FragmentParser.render_fragment(fragment4))}")
IO.puts("")

# Example 5: Parse multiple sections with various tag configurations
IO.puts("5. Multiple sections with different tag configurations:")

multi_text = """
* Personal tasks :personal:
** TODO Buy groceries :shopping:urgent:
** DONE Exercise :health:
* Work projects :work:
** TODO [#A] Client presentation :work:presentation:deadline:
** Project review :work:review:
"""

fragments = Org.FragmentParser.parse_fragments(multi_text)
sections = Enum.filter(fragments, fn f -> f.type == :section end)

Enum.each(sections, fn section ->
  IO.puts("   #{section.content.title}")
  IO.puts("     - TODO: #{inspect(section.content.todo_keyword)}")
  IO.puts("     - Priority: #{inspect(section.content.priority)}")
  IO.puts("     - Tags: #{inspect(section.content.tags)}")
  IO.puts("     - Rendered: #{inspect(Org.FragmentParser.render_fragment(section))}")
  IO.puts("")
end)

IO.puts("=== Tag Support Complete! ===")
