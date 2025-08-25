defmodule Org.FragmentParserTest do
  use ExUnit.Case
  doctest Org.FragmentParser

  alias Org.{CodeBlock, FragmentParser, List, Paragraph, Table}

  describe "parse_fragment/2" do
    test "parses section fragment" do
      text = "** TODO [#A] Important task"
      fragment = FragmentParser.parse_fragment(text)

      assert fragment.type == :section
      assert fragment.content.title == "Important task"
      assert fragment.content.todo_keyword == "TODO"
      assert fragment.content.priority == "A"
      assert fragment.original_text == text
      assert fragment.range == {{1, 1}, {1, 28}}
    end

    test "parses section fragment without todo or priority" do
      text = "* Simple section"
      fragment = FragmentParser.parse_fragment(text)

      assert fragment.type == :section
      assert fragment.content.title == "Simple section"
      assert fragment.content.todo_keyword == nil
      assert fragment.content.priority == nil
    end

    test "parses paragraph fragment" do
      text = "This is a simple paragraph."
      fragment = FragmentParser.parse_fragment(text, type: :content)

      assert fragment.type == :content
      assert %Paragraph{} = fragment.content
      assert fragment.content.lines == [text]
    end

    test "parses formatted text fragment" do
      text = "This is *bold* and /italic/ text."
      fragment = FragmentParser.parse_fragment(text, type: :text)

      assert fragment.type == :text
      # Content is a FormattedText struct, not a list
      assert is_struct(fragment.content)
      assert is_list(fragment.content.spans)
    end

    test "parses list fragment" do
      text = "- First item\n- Second item\n  - Nested item"
      fragment = FragmentParser.parse_fragment(text, type: :content)

      assert fragment.type == :content
      assert %List{} = fragment.content
      assert length(fragment.content.items) == 2

      [first, second] = fragment.content.items
      assert first.content == "First item"
      assert first.ordered == false
      assert second.content == "Second item"
      assert length(second.children) == 1

      nested = hd(second.children)
      assert nested.content == "Nested item"
      assert nested.indent == 1
    end

    test "parses ordered list fragment" do
      text = "1. First item\n2. Second item"
      fragment = FragmentParser.parse_fragment(text, type: :content)

      assert fragment.type == :content
      assert %List{} = fragment.content
      assert length(fragment.content.items) == 2

      [first, second] = fragment.content.items
      assert first.content == "First item"
      assert first.ordered == true
      assert first.number == 1
      assert second.number == 2
    end

    test "parses table fragment" do
      text = "| Name | Age |\n|------|-----|\n| John | 25  |"
      fragment = FragmentParser.parse_fragment(text, type: :content)

      assert fragment.type == :content
      assert %Table{} = fragment.content
      assert length(fragment.content.rows) == 3

      [header, separator, data] = fragment.content.rows
      assert %Table.Row{cells: ["Name", "Age"]} = header
      assert %Table.Separator{} = separator
      assert %Table.Row{cells: ["John", "25"]} = data
    end

    test "parses code block fragment" do
      text = "#+BEGIN_SRC elixir\ndefmodule Test do\n  def hello, do: :world\nend\n#+END_SRC"
      fragment = FragmentParser.parse_fragment(text, type: :content)

      assert fragment.type == :content
      assert %CodeBlock{} = fragment.content
      assert fragment.content.lang == "elixir"
      assert length(fragment.content.lines) == 3
      assert "defmodule Test do" in fragment.content.lines
    end

    test "auto-detects fragment type for section" do
      text = "*** Section title"
      fragment = FragmentParser.parse_fragment(text)

      assert fragment.type == :section
    end

    test "auto-detects fragment type for list" do
      text = "- List item"
      fragment = FragmentParser.parse_fragment(text)

      assert fragment.type == :content
      assert %List{} = fragment.content
    end

    test "auto-detects fragment type for table" do
      text = "| col1 | col2 |"
      fragment = FragmentParser.parse_fragment(text)

      assert fragment.type == :content
      assert %Table{} = fragment.content
    end

    test "tracks position information" do
      text = "* Section"
      fragment = FragmentParser.parse_fragment(text, start_position: {5, 10})

      assert fragment.range == {{5, 10}, {5, 19}}
    end

    test "preserves context information" do
      text = "  * Indented section"
      fragment = FragmentParser.parse_fragment(text)

      assert fragment.context.indent_level == 2
      assert fragment.context.section_level == 1
    end

    test "handles empty text" do
      fragment = FragmentParser.parse_fragment("")

      assert fragment.type == :line
      assert fragment.content == ""
    end
  end

  describe "parse_fragments/2" do
    test "parses multiple fragments" do
      text = "* Section 1\n\nSome content\n\n* Section 2"
      fragments = FragmentParser.parse_fragments(text)

      assert length(fragments) == 3

      [sec1, content, sec2] = fragments
      assert sec1.type == :section
      assert sec1.content.title == "Section 1"

      assert content.type == :line
      assert content.content == "Some content"

      assert sec2.type == :section
      assert sec2.content.title == "Section 2"
    end

    test "handles empty lines correctly" do
      text = "* Section\n\n\nContent\n\n"
      fragments = FragmentParser.parse_fragments(text)

      # Empty lines are skipped
      assert length(fragments) == 2
      assert Enum.at(fragments, 0).type == :section
      assert Enum.at(fragments, 1).type == :line
    end

    test "tracks line numbers correctly" do
      text = "Line 1\nLine 2\nLine 3"
      fragments = FragmentParser.parse_fragments(text)

      assert length(fragments) == 3
      assert Enum.at(fragments, 0).range == {{1, 1}, {1, 7}}
      assert Enum.at(fragments, 1).range == {{2, 1}, {2, 7}}
      assert Enum.at(fragments, 2).range == {{3, 1}, {3, 7}}
    end
  end

  describe "update_fragment/2" do
    test "updates fragment content" do
      original = FragmentParser.parse_fragment("* Old Title")
      updated = FragmentParser.update_fragment(original, "* New Title")

      assert updated.content.title == "New Title"
      assert updated.type == :section
      # Position preserved
      assert updated.range == original.range
    end

    test "preserves context during update" do
      original = FragmentParser.parse_fragment("  * Indented", start_position: {5, 3})
      updated = FragmentParser.update_fragment(original, "  * Updated")

      assert updated.context.indent_level == 2
      assert elem(updated.range, 0) == {5, 3}
    end
  end

  describe "render_fragment/1" do
    test "renders section fragment" do
      fragment = FragmentParser.parse_fragment("** TODO [#A] Task")
      rendered = FragmentParser.render_fragment(fragment)

      assert rendered == "** TODO [#A] Task"
    end

    test "renders paragraph fragment" do
      text = "This is a paragraph."
      fragment = FragmentParser.parse_fragment(text, type: :content)
      rendered = FragmentParser.render_fragment(fragment)

      assert rendered == text
    end

    test "renders list fragment" do
      text = "- First\n- Second\n  - Nested"
      fragment = FragmentParser.parse_fragment(text, type: :content)
      rendered = FragmentParser.render_fragment(fragment)

      assert rendered =~ "- First"
      assert rendered =~ "- Second"
      assert rendered =~ "  - Nested"
    end

    test "renders table fragment" do
      text = "| A | B |\n|---|---|"
      fragment = FragmentParser.parse_fragment(text, type: :content)
      rendered = FragmentParser.render_fragment(fragment)

      assert rendered =~ "| A | B |"
      # Separator may be formatted differently
      assert rendered =~ "|----------|"
    end

    test "renders code block fragment" do
      text = "#+BEGIN_SRC python\nprint('hello')\n#+END_SRC"
      fragment = FragmentParser.parse_fragment(text, type: :content)
      rendered = FragmentParser.render_fragment(fragment)

      assert rendered =~ "#+BEGIN_SRC python"
      assert rendered =~ "print('hello')"
      assert rendered =~ "#+END_SRC"
    end
  end

  describe "context building" do
    test "detects section level" do
      fragment = FragmentParser.parse_fragment("*** Deep section")
      assert fragment.context.section_level == 3
    end

    test "detects indent level" do
      fragment = FragmentParser.parse_fragment("    Indented content")
      assert fragment.context.indent_level == 4
    end

    test "detects list context" do
      fragment = FragmentParser.parse_fragment("  - List item")

      assert fragment.context.list_context != nil
      assert fragment.context.list_context.type == :unordered
      assert fragment.context.list_context.base_indent == 2
    end

    test "detects ordered list context" do
      fragment = FragmentParser.parse_fragment("3. Third item")

      assert fragment.context.list_context != nil
      assert fragment.context.list_context.type == :ordered
      assert fragment.context.list_context.item_number == 3
    end
  end

  describe "edge cases" do
    test "handles partial section headers" do
      text = "* tod hello"
      fragment = FragmentParser.parse_fragment(text)

      # Should parse as section with "tod hello" as title
      assert fragment.type == :section
      assert fragment.content.title == "tod hello"
      assert fragment.content.todo_keyword == nil
      assert fragment.content.priority == nil
    end

    test "handles section with weird spacing" do
      text = "*    wassup"
      fragment = FragmentParser.parse_fragment(text)

      # Should parse as section with "wassup" as title
      assert fragment.type == :section
      assert fragment.content.title == "wassup"
    end

    test "handles incomplete list items" do
      text = "* wassup \n - test1\n - test2\n -"
      fragments = FragmentParser.parse_fragments(text)

      # Should have section and list items
      assert length(fragments) >= 3

      # First should be section
      section_fragment = Enum.at(fragments, 0)
      assert section_fragment.type == :section
      assert section_fragment.content.title == "wassup"

      # Should handle incomplete list item gracefully - it might be parsed as :line or :content
      incomplete_items =
        Enum.filter(fragments, fn f ->
          case f.type do
            :line -> String.contains?(f.content, "-")
            # Could be parsed as list content
            :content -> true
            _ -> false
          end
        end)

      assert length(incomplete_items) > 0

      # All fragments should be successfully parsed (no nil content)
      Enum.each(fragments, fn fragment ->
        assert fragment.content != nil
      end)
    end

    test "handles list fragment with incomplete item" do
      text = "- test1\n- test2\n-"
      fragment = FragmentParser.parse_fragment(text, type: :content)

      assert fragment.type == :content
      assert %List{} = fragment.content

      # Should have parsed the complete items
      complete_items =
        Enum.filter(fragment.content.items, fn item ->
          item.content != ""
        end)

      assert length(complete_items) >= 2

      # May have an empty item for the incomplete "-"
      items_with_content = Enum.map(fragment.content.items, & &1.content)
      assert "test1" in items_with_content
      assert "test2" in items_with_content
    end

    test "handles malformed section headers" do
      text = "*Not a real header"
      fragment = FragmentParser.parse_fragment(text)

      # Should fall back to text parsing due to * character
      assert fragment.type == :text
      # Content is a FormattedText struct when type is :text
      assert is_struct(fragment.content)
    end

    test "handles incomplete table rows" do
      text = "| incomplete"
      fragment = FragmentParser.parse_fragment(text, type: :content)

      # Should still create a table structure
      assert fragment.type == :content
      assert %Table{} = fragment.content
    end

    test "handles code blocks without end marker" do
      text = "#+BEGIN_SRC\nsome code"
      fragment = FragmentParser.parse_fragment(text, type: :content)

      assert fragment.type == :content
      assert %Paragraph{} = fragment.content
      assert fragment.content.lines == [text]
    end

    test "handles very long lines" do
      long_text = String.duplicate("word ", 1000)
      fragment = FragmentParser.parse_fragment(long_text)

      assert fragment.type == :line
      assert String.length(fragment.content) > 4000
    end

    test "handles unicode content" do
      text = "* 中文标题"
      fragment = FragmentParser.parse_fragment(text)

      assert fragment.type == :section
      assert fragment.content.title == "中文标题"
    end
  end
end
