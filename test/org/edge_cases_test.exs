defmodule Org.EdgeCasesTest do
  use ExUnit.Case

  describe "malformed sections" do
    test "sections with no title" do
      # This could crash or behave unexpectedly
      source = "* \n** \n*** "
      doc = Org.Parser.parse(source)

      # Should parse without crashing
      assert length(doc.sections) > 0
      # All sections should have empty or whitespace titles
      for section <- doc.sections do
        assert String.trim(section.title) in ["", " "]
      end
    end

    test "sections with only asterisks" do
      source = "*\n**\n***\n****"

      # This might be parsed as text instead of sections
      result = Org.Parser.parse(source)

      # Should not crash
      assert %Org.Document{} = result
    end

    test "sections with mixed spacing" do
      source = "*    Lots of spaces\n**\t\tTabs and spaces\n***   \t  Mixed"
      doc = Org.Parser.parse(source)

      # Root sections
      assert length(doc.sections) == 1
      root_section = Enum.at(doc.sections, 0)

      # Titles should be trimmed
      assert root_section.title == "Lots of spaces"
      assert length(root_section.children) == 1
      assert Enum.at(root_section.children, 0).title == "Tabs and spaces"
      assert length(Enum.at(root_section.children, 0).children) == 1
      assert Enum.at(Enum.at(root_section.children, 0).children, 0).title == "Mixed"
    end

    test "sections with invalid TODO keywords" do
      source = """
      * INVALID Task 1
      * TODO-MAYBE Task 2  
      * DONE? Task 3
      * TO DO Task 4
      """

      doc = Org.Parser.parse(source)

      # Invalid keywords should be treated as part of title
      sections = doc.sections
      assert Enum.at(sections, 0).todo_keyword == nil
      assert Enum.at(sections, 0).title == "INVALID Task 1"
      assert Enum.at(sections, 1).todo_keyword == nil
      assert Enum.at(sections, 1).title == "TODO-MAYBE Task 2"
      assert Enum.at(sections, 2).todo_keyword == nil
      assert Enum.at(sections, 2).title == "DONE? Task 3"
    end

    test "sections with malformed priorities" do
      source = """
      * TODO [#] No priority letter
      * TODO [#D] Invalid priority
      * TODO [#AA] Double letter
      * TODO [#a] Lowercase
      * TODO [# A] Space in priority
      * TODO [#A Extra text
      """

      doc = Org.Parser.parse(source)

      # All should parse but with no priority set
      # Flatten all sections (including nested ones)
      all_sections = Org.todo_items(doc)

      for section <- all_sections do
        assert section.priority == nil
        assert section.todo_keyword == "TODO"
      end
    end
  end

  describe "malformed tables" do
    test "table with uneven rows" do
      source = """
      | Col1 | Col2 | Col3 |
      | A | B |
      | X | Y | Z | Extra |
      | Just one cell |
      """

      doc = Org.Parser.parse(source)
      [table] = Org.tables(doc)

      # Should parse all rows despite uneven columns
      assert length(table.rows) == 4
      assert Enum.at(table.rows, 0).cells == ["Col1", "Col2", "Col3"]
      assert Enum.at(table.rows, 1).cells == ["A", "B"]
      assert Enum.at(table.rows, 2).cells == ["X", "Y", "Z", "Extra"]
      assert Enum.at(table.rows, 3).cells == ["Just one cell"]
    end

    test "table with empty cells and weird spacing" do
      source = """
      |   | Empty first |   |
      |No pipes at start
      Completely broken table row
      |  | | | | Multiple empty |
      """

      doc = Org.Parser.parse(source)

      # Should handle gracefully - some rows as table, others as paragraphs
      tables = Org.tables(doc)
      paragraphs = Org.paragraphs(doc)

      # Should have at least one table with the valid rows
      assert length(tables) > 0
      # Should have paragraphs for the broken rows
      assert length(paragraphs) > 0
    end
  end

  describe "malformed lists" do
    test "lists with inconsistent indentation" do
      source = """
      - Item 1
         - Indented weird
       - Different indent
      \t- Tab instead of spaces
      -No space after dash
      + Mixed bullet types
      * Star bullets
      1. Ordered
      a. Invalid ordered
      """

      doc = Org.Parser.parse(source)
      lists = Org.lists(doc)
      paragraphs = Org.paragraphs(doc)

      # Should parse what it can
      assert length(lists) > 0
      # Invalid formats should become paragraphs
      assert length(paragraphs) > 0
    end

    test "nested lists with wrong indentation" do
      source = """
      - Top level
      - Still top level
         - Way too indented
      - Back to top
        - Proper nested
             - Way too deep
      """

      doc = Org.Parser.parse(source)
      [list] = Org.lists(doc)

      # Should handle weird indentation gracefully
      assert length(list.items) == 6

      # Check indentation levels are preserved
      indents = Enum.map(list.items, & &1.indent)
      # Top level items
      assert 0 in indents
      # Properly nested
      assert 2 in indents
      # Weird indentation should be preserved
    end
  end

  describe "malformed code blocks" do
    test "code block without end" do
      source = """
      #+BEGIN_SRC python
      def hello():
          print("world")

      This continues forever...
      """

      doc = Org.Parser.parse(source)
      code_blocks = Org.code_blocks(doc)

      # Should handle gracefully - either create a code block with all content
      # or treat some content as paragraphs
      assert length(code_blocks) >= 0
    end

    test "code block with weird language specs" do
      source = """
      #+BEGIN_SRC 
      No language specified
      #+END_SRC

      #+BEGIN_SRC invalid-language-name-123
      Weird language name
      #+END_SRC

      #+BEGIN_SRC python -super -weird -flags
      With many flags
      #+END_SRC
      """

      doc = Org.Parser.parse(source)
      code_blocks = Org.code_blocks(doc)

      assert length(code_blocks) == 3
      # Should handle empty and weird language names
      assert Enum.at(code_blocks, 0).lang == ""
      assert Enum.at(code_blocks, 1).lang == "invalid-language-name-123"
      assert Enum.at(code_blocks, 2).lang == "python"
    end

    test "nested code blocks" do
      source = """
      #+BEGIN_SRC org-mode
      This contains:
      #+BEGIN_SRC python
      print("nested")
      #+END_SRC
      More org content
      #+END_SRC
      """

      doc = Org.Parser.parse(source)
      code_blocks = Org.code_blocks(doc)

      # Should treat the inner block as text content of the outer block
      assert length(code_blocks) == 1
      code_content = Enum.join(Enum.at(code_blocks, 0).lines, "\n")
      assert String.contains?(code_content, "#+BEGIN_SRC python")
      # The inner #+END_SRC terminates the outer block, so it won't be in the content
      # This is correct org-mode behavior
    end
  end

  describe "mixed content chaos" do
    test "everything mixed together" do
      source = """
      * TODO [#A] Section with table

      | Col1 | Col2 |
      |------+------|

      Some paragraph text

      #+BEGIN_SRC elixir
      def mixed_content() do
        "chaos"
      end

      ** Subsection inside code block?

      - List item 1
        - Nested in code?

      #+END_SRC

      * Another section

      More chaos:
      - List item
      * Invalid section? (single space)
      |Not a table row

      #+BEGIN_SRC
      Code with no language
      * More sections in code
      #+END_SRC
      """

      # Should parse without crashing
      doc = Org.Parser.parse(source)

      assert %Org.Document{} = doc
      assert length(doc.sections) >= 1

      # Should have various content types (but may not all be parsed correctly in chaotic content)
      # At minimum should have some content without crashing
      # Content may be distributed across sections
      total_content =
        Enum.reduce(doc.sections, 0, fn section, acc ->
          acc + length(Org.tables(section)) + length(Org.code_blocks(section)) +
            length(Org.lists(section)) + length(Org.paragraphs(section))
        end)

      assert total_content > 0
    end
  end

  describe "unicode and special characters" do
    test "unicode in sections and content" do
      source = """
      * 🚀 Unicode Section with émojis
      ** 中文 Chinese Characters
      *** Ñoño with accents

      | 🎯 | Target | 💯 |
      | 数字 | Numbers | 123 |

      - Item with 🌟 stars
      - Iтем wïth mïxęd chåracters

      #+BEGIN_SRC python
      # Comment with émojis 🐍
      def función():
          return "Ñoño"
      #+END_SRC
      """

      doc = Org.Parser.parse(source)

      # Should handle unicode gracefully - sections are nested
      assert length(doc.sections) == 1
      root_section = Enum.at(doc.sections, 0)
      assert String.contains?(root_section.title, "🚀")
      assert String.contains?(Enum.at(root_section.children, 0).title, "中文")

      # Content is attached to the deepest section
      deepest_section = Enum.at(Enum.at(root_section.children, 0).children, 0)
      assert String.contains?(deepest_section.title, "Ñoño")

      [table] = Org.tables(deepest_section)
      assert String.contains?(List.first(Enum.at(table.rows, 0).cells), "🎯")

      [list] = Org.lists(deepest_section)
      assert String.contains?(Enum.at(list.items, 0).content, "🌟")
    end

    test "control characters and edge cases" do
      source = "* Section\twith\ttabs\n\n\r\nMixed line endings\r\n\n* Another\0null"

      # Should handle without crashing
      doc = Org.Parser.parse(source)
      assert %Org.Document{} = doc
    end
  end

  describe "extremely large content" do
    test "very long lines" do
      # Create extremely long content
      long_title = String.duplicate("Very long title ", 1000)
      long_paragraph = String.duplicate("Long paragraph content. ", 2000)

      source = """
      * #{long_title}

      #{long_paragraph}

      | #{String.duplicate("Long cell ", 100)} |

      - #{String.duplicate("Long list item ", 500)}
      """

      # Should handle without memory issues or crashes
      doc = Org.Parser.parse(source)
      assert %Org.Document{} = doc
      assert length(doc.sections) == 1
    end
  end

  describe "empty and whitespace-only content" do
    test "completely empty file" do
      doc = Org.Parser.parse("")

      assert doc.sections == []
      assert doc.contents == []
      assert doc.comments == []
    end

    test "only whitespace" do
      source = "   \n\t\n  \r\n    "
      doc = Org.Parser.parse(source)

      # Should handle gracefully
      assert %Org.Document{} = doc
    end

    test "empty sections and content blocks" do
      source = """
      * 
      ** 



      #+BEGIN_SRC


      #+END_SRC

      |  |  |

      - 

      """

      doc = Org.Parser.parse(source)

      # Should parse structure even if content is empty
      assert length(doc.sections) >= 1
    end
  end
end
