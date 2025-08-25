#!/usr/bin/env elixir

# Add the lib directory to the code path
Code.prepend_path("../../lib")

# Start the OTP application to make modules available
Application.ensure_all_started(:org)

# Example demonstrating custom TODO keyword support
IO.puts("=== Org-mode Custom TODO Keywords Example ===\n")

alias Org.FragmentParser

# Example 1: Default keywords (standard org-mode behavior)
IO.puts("1. Default org-mode keywords:")
text1 = "** TODO [#A] Review pull request :code:"
fragment1 = FragmentParser.parse_fragment(text1)
IO.puts("   Original: #{inspect(text1)}")
IO.puts("   Keyword: #{inspect(fragment1.content.todo_keyword)}")
IO.puts("   Title: #{inspect(fragment1.content.title)}")
IO.puts("")

# Example 2: Custom workflow sequence (development workflow)
IO.puts("2. Custom workflow sequence (Development):")

dev_workflow =
  FragmentParser.workflow_sequence(
    ["TODO", "INPROGRESS", "REVIEW", "TESTING"],
    ["DONE", "CANCELLED", "DEFERRED"]
  )

dev_config = FragmentParser.custom_keyword_config([dev_workflow])

examples2 = [
  "* TODO Implement feature X",
  "** INPROGRESS Fix critical bug",
  "*** REVIEW Code changes for module Y",
  "* TESTING Integration tests",
  "** DONE Feature deployment",
  "* CANCELLED Outdated requirement"
]

Enum.each(examples2, fn text ->
  fragment = FragmentParser.parse_fragment(text, keyword_config: dev_config)
  IO.puts("   #{fragment.content.todo_keyword || "nil"}: #{fragment.content.title}")
end)

IO.puts("")

# Example 3: Type-based keywords (team assignment)
IO.puts("3. Type-based keywords (Team assignment):")

team_types =
  FragmentParser.type_sequence(
    ["Alice", "Bob", "Carol", "David"],
    ["COMPLETED"]
  )

team_config = FragmentParser.custom_keyword_config([team_types])

examples3 = [
  "* Alice Design user interface :ui:",
  "** Bob Implement backend API :backend:",
  "*** Carol Write documentation :docs:",
  "* David Setup deployment :devops:",
  "** COMPLETED Database migration"
]

Enum.each(examples3, fn text ->
  fragment = FragmentParser.parse_fragment(text, keyword_config: team_config)
  assignee = fragment.content.todo_keyword || "Unassigned"
  IO.puts("   #{assignee}: #{fragment.content.title}")
end)

IO.puts("")

# Example 4: Multiple sequences (bug tracking + regular tasks)
IO.puts("4. Multiple sequences (Bug tracking + Regular tasks):")
regular_seq = FragmentParser.workflow_sequence(["TODO", "DOING"], ["DONE"])

bug_seq =
  FragmentParser.workflow_sequence(
    ["BUG", "INVESTIGATING", "FIXING", "VALIDATING"],
    ["FIXED", "WONTFIX", "DUPLICATE"]
  )

multi_config = FragmentParser.custom_keyword_config([regular_seq, bug_seq])

examples4 = [
  "* TODO Add user preferences",
  "** DOING Refactor authentication",
  "*** DONE Update documentation",
  "* BUG Login fails on mobile",
  "** INVESTIGATING Memory leak in parser",
  "*** FIXING Performance issues",
  "** VALIDATING Security patches",
  "* FIXED CSS alignment issues",
  "** WONTFIX Minor UI inconsistency",
  "*** DUPLICATE Reported elsewhere"
]

IO.puts("   Regular workflow tasks:")

examples4
|> Enum.filter(fn text ->
  fragment = FragmentParser.parse_fragment(text, keyword_config: multi_config)
  fragment.content.todo_keyword in ["TODO", "DOING", "DONE"]
end)
|> Enum.each(fn text ->
  fragment = FragmentParser.parse_fragment(text, keyword_config: multi_config)
  IO.puts("     #{fragment.content.todo_keyword}: #{fragment.content.title}")
end)

IO.puts("   Bug tracking tasks:")

examples4
|> Enum.filter(fn text ->
  fragment = FragmentParser.parse_fragment(text, keyword_config: multi_config)
  fragment.content.todo_keyword in ["BUG", "INVESTIGATING", "FIXING", "VALIDATING", "FIXED", "WONTFIX", "DUPLICATE"]
end)
|> Enum.each(fn text ->
  fragment = FragmentParser.parse_fragment(text, keyword_config: multi_config)
  IO.puts("     #{fragment.content.todo_keyword}: #{fragment.content.title}")
end)

IO.puts("")

# Example 5: Complex example with priorities and tags
IO.puts("5. Complex example with priorities and tags:")

complex_seq =
  FragmentParser.workflow_sequence(
    ["PROPOSAL", "APPROVED", "ASSIGNED", "INWORK", "REVIEW"],
    ["MERGED", "REJECTED", "ONHOLD"]
  )

complex_config = FragmentParser.custom_keyword_config([complex_seq])

complex_text = "** ASSIGNED [#A] Implement OAuth integration :security:api:urgent:"
complex_fragment = FragmentParser.parse_fragment(complex_text, keyword_config: complex_config)
rendered = FragmentParser.render_fragment(complex_fragment)

IO.puts("   Original: #{inspect(complex_text)}")
IO.puts("   Keyword: #{inspect(complex_fragment.content.todo_keyword)}")
IO.puts("   Priority: #{inspect(complex_fragment.content.priority)}")
IO.puts("   Title: #{inspect(complex_fragment.content.title)}")
IO.puts("   Tags: #{inspect(complex_fragment.content.tags)}")
IO.puts("   Rendered: #{inspect(rendered)}")
IO.puts("")

# Example 6: Testing edge cases
IO.puts("6. Edge cases:")

edge_config =
  FragmentParser.custom_keyword_config([
    FragmentParser.workflow_sequence(["CUSTOM"], ["FINISHED"])
  ])

edge_cases = [
  "* UNKNOWN This keyword is not configured",
  "* CUSTOM Valid custom keyword",
  "* Regular section without keywords",
  "** FINISHED Task completed"
]

Enum.each(edge_cases, fn text ->
  fragment = FragmentParser.parse_fragment(text, keyword_config: edge_config)
  keyword = fragment.content.todo_keyword || "nil"
  IO.puts("   #{keyword}: #{fragment.content.title}")
end)

IO.puts("")
IO.puts("=== Custom Keywords Support Complete! ===")
