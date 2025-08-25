#!/usr/bin/env elixir

# Basic Fragment Parsing Example
# Demonstrates how to parse individual org-mode elements

IO.puts("🧩 Fragment Parsing - Basic Usage")
IO.puts("=" |> String.duplicate(40))

# Parse different types of fragments
fragments = [
  {"Section Header", "** TODO [#A] Important task"},
  {"Simple Section", "* Simple section title"},
  {"Paragraph", "This is a simple paragraph with some text."},
  {"Formatted Text", "This has *bold* and /italic/ formatting."},
  {"List Items", "- First item\n- Second item\n  - Nested item"},
  {"Ordered List", "1. First step\n2. Second step\n3. Final step"},
  {"Table", "| Name | Age | City |\n|------|-----|------|\n| John | 25  | NYC  |"},
  {"Code Block", "#+BEGIN_SRC elixir\ndefmodule Test do\n  def hello, do: :world\nend\n#+END_SRC"},
  {"Partial Section", "* tod hello"},
  {"Incomplete List", "- test1\n- test2\n-"}
]

IO.puts("\n📝 Parsing Individual Fragments:")
IO.puts("-" |> String.duplicate(40))

Enum.each(fragments, fn {name, text} ->
  IO.puts("\n#{name}:")
  IO.puts("Input: #{inspect(text)}")

  fragment = Org.parse_fragment(text)
  IO.puts("Type: #{fragment.type}")
  IO.puts("Range: #{inspect(fragment.range)}")

  case fragment.type do
    :section ->
      section = fragment.content
      IO.puts("Title: \"#{section.title}\"")
      if section.todo_keyword, do: IO.puts("TODO: #{section.todo_keyword}")
      if section.priority, do: IO.puts("Priority: [##{section.priority}]")

    :content when is_struct(fragment.content, Org.List) ->
      list = fragment.content
      IO.puts("List items: #{length(list.items)}")

      Enum.with_index(list.items)
      |> Enum.each(fn {item, i} ->
        prefix = if item.ordered, do: "#{item.number || i + 1}.", else: "-"
        indent = String.duplicate("  ", item.indent)
        IO.puts("  #{indent}#{prefix} #{item.content}")
      end)

    :content when is_struct(fragment.content, Org.Table) ->
      table = fragment.content
      IO.puts("Table rows: #{length(table.rows)}")

      Enum.each(table.rows, fn
        %Org.Table.Row{cells: cells} -> IO.puts("  | #{Enum.join(cells, " | ")} |")
        %Org.Table.Separator{} -> IO.puts("  |" <> String.duplicate("-", 20) <> "|")
      end)

    :content when is_struct(fragment.content, Org.CodeBlock) ->
      code = fragment.content
      IO.puts("Language: #{code.lang}")
      IO.puts("Lines: #{length(code.lines)}")
      IO.puts("Preview: #{Enum.at(code.lines, 0, "")}")

    :content when is_struct(fragment.content, Org.Paragraph) ->
      para = fragment.content
      IO.puts("Lines: #{length(para.lines)}")
      IO.puts("Content: \"#{Enum.join(para.lines, " ")}\"")

    :text ->
      if is_struct(fragment.content, Org.FormattedText) do
        IO.puts("Formatted text spans: #{length(fragment.content.spans)}")
      else
        IO.puts("Formatted text elements: #{if is_list(fragment.content), do: length(fragment.content), else: 1}")
      end

    :line ->
      IO.puts("Content: \"#{fragment.content}\"")
  end

  IO.puts("Context - Indent: #{fragment.context.indent_level || 0}")

  if fragment.context.section_level do
    IO.puts("Context - Section level: #{fragment.context.section_level}")
  end
end)

IO.puts("\n🔄 Fragment Rendering:")
IO.puts("-" |> String.duplicate(40))

# Demonstrate rendering fragments back to text
# Take first example
{_name, text} = Enum.at(fragments, 0)
fragment = Org.parse_fragment(text)
rendered = Org.render_fragment(fragment)

IO.puts("Original: #{inspect(text)}")
IO.puts("Rendered: #{inspect(rendered)}")
IO.puts("Round-trip successful: #{text == rendered}")

IO.puts("\n📊 Multi-Fragment Parsing:")
IO.puts("-" |> String.duplicate(40))

# Parse multiple fragments from text
multi_text = """
* Project Overview
This is the main project description.

** TODO [#A] Critical Task  
Important work that needs to be done.

- First requirement
- Second requirement
  - Sub-requirement A
  - Sub-requirement B

| Task | Status | Assignee |
|------|--------|----------|
| Setup | Done | Alice |
| Development | In Progress | Bob |

#+BEGIN_SRC bash
# Installation commands
npm install
npm start
#+END_SRC
"""

IO.puts("Parsing multi-line text with #{String.split(multi_text, "\n") |> length()} lines")

fragments_list = Org.parse_fragments(multi_text)
IO.puts("Found #{length(fragments_list)} fragments")

Enum.with_index(fragments_list)
|> Enum.each(fn {frag, i} ->
  IO.puts("#{i + 1}. #{frag.type} at #{inspect(elem(frag.range, 0))}")
end)

IO.puts("\n✅ Basic fragment parsing examples completed!")
IO.puts("Next: Try incremental_editing.exs for advanced usage")
