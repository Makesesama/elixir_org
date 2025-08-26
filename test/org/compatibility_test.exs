defmodule Org.CompatibilityTest do
  use ExUnit.Case

  @moduledoc """
  Test suite based on the official org-mode test suite to ensure compatibility
  with the reference implementation from: 
  https://github.com/bzg/org-mode/tree/main/testing/lisp/test-org-element.el
  """

  describe "headline parsing (official compatibility)" do
    test "basic headline structure" do
      source = "* Headline"
      doc = Org.Parser.parse(source)

      assert length(doc.sections) == 1
      section = Enum.at(doc.sections, 0)
      assert section.title == "Headline"
      assert section.todo_keyword == nil
      assert section.priority == nil
    end

    test "headlines with TODO keywords" do
      source = """
      * TODO Task 1
      * DONE Completed Task
      * Regular Headline
      """

      doc = Org.Parser.parse(source)
      assert length(doc.sections) == 3

      sections = doc.sections
      assert Enum.at(sections, 0).todo_keyword == "TODO"
      assert Enum.at(sections, 0).title == "Task 1"

      assert Enum.at(sections, 1).todo_keyword == "DONE"
      assert Enum.at(sections, 1).title == "Completed Task"

      assert Enum.at(sections, 2).todo_keyword == nil
      assert Enum.at(sections, 2).title == "Regular Headline"
    end

    test "headlines with priorities" do
      source = """
      * TODO [#A] High Priority
      * TODO [#B] Medium Priority  
      * TODO [#C] Low Priority
      """

      doc = Org.Parser.parse(source)
      sections = doc.sections

      assert Enum.at(sections, 0).priority == "A"
      assert Enum.at(sections, 0).title == "High Priority"

      assert Enum.at(sections, 1).priority == "B"
      assert Enum.at(sections, 1).title == "Medium Priority"

      assert Enum.at(sections, 2).priority == "C"
      assert Enum.at(sections, 2).title == "Low Priority"
    end

    test "nested headlines" do
      source = """
      * Level 1
      ** Level 2
      *** Level 3
      ** Another Level 2
      * Another Level 1
      """

      doc = Org.Parser.parse(source)
      assert length(doc.sections) == 2

      first_section = Enum.at(doc.sections, 0)
      assert first_section.title == "Level 1"
      assert length(first_section.children) == 2

      level2_first = Enum.at(first_section.children, 0)
      assert level2_first.title == "Level 2"
      assert length(level2_first.children) == 1

      level3 = Enum.at(level2_first.children, 0)
      assert level3.title == "Level 3"

      level2_second = Enum.at(first_section.children, 1)
      assert level2_second.title == "Another Level 2"

      second_section = Enum.at(doc.sections, 1)
      assert second_section.title == "Another Level 1"
    end
  end

  describe "list parsing (official compatibility)" do
    test "unordered lists with different bullets" do
      source = """
      - Item 1
      + Item 2
      - Item 3
      """

      doc = Org.Parser.parse(source)
      [list] = Org.lists(doc)

      assert length(list.items) == 3
      assert Enum.at(list.items, 0).content == "Item 1"
      assert Enum.at(list.items, 0).ordered == false
      assert Enum.at(list.items, 1).content == "Item 2"
      assert Enum.at(list.items, 2).content == "Item 3"
    end

    test "ordered lists" do
      source = """
      1. First item
      2. Second item
      3. Third item
      """

      doc = Org.Parser.parse(source)
      [list] = Org.lists(doc)

      assert length(list.items) == 3
      assert Enum.at(list.items, 0).ordered == true
      assert Enum.at(list.items, 0).number == 1
      assert Enum.at(list.items, 0).content == "First item"
    end

    test "nested lists" do
      source = """
      - Top level
        - Nested item 1
        - Nested item 2
      - Another top level
      """

      doc = Org.Parser.parse(source)
      [list] = Org.lists(doc)

      # Test the nested structure
      nested_items = Org.List.build_nested(list.items)
      assert length(nested_items) == 2

      first_item = Enum.at(nested_items, 0)
      assert first_item.content == "Top level"
      assert length(first_item.children) == 2

      assert Enum.at(first_item.children, 0).content == "Nested item 1"
      assert Enum.at(first_item.children, 1).content == "Nested item 2"
    end
  end

  describe "table parsing (official compatibility)" do
    test "simple table" do
      source = """
      | Header 1 | Header 2 |
      | Cell 1   | Cell 2   |
      | Cell 3   | Cell 4   |
      """

      doc = Org.Parser.parse(source)
      [table] = Org.tables(doc)

      assert length(table.rows) == 3

      header_row = Enum.at(table.rows, 0)
      assert header_row.cells == ["Header 1", "Header 2"]

      first_data_row = Enum.at(table.rows, 1)
      assert first_data_row.cells == ["Cell 1", "Cell 2"]
    end

    test "table with separator" do
      source = """
      | Header 1 | Header 2 |
      |----------+----------|
      | Data 1   | Data 2   |
      """

      doc = Org.Parser.parse(source)
      [table] = Org.tables(doc)

      assert length(table.rows) == 3

      # Check separator
      separator = Enum.at(table.rows, 1)
      assert %Org.Table.Separator{} = separator
    end
  end

  describe "code block parsing (official compatibility)" do
    test "basic code block" do
      source = """
      #+BEGIN_SRC python
      def hello():
          print("Hello, World!")
      #+END_SRC
      """

      doc = Org.Parser.parse(source)
      [code_block] = Org.code_blocks(doc)

      assert code_block.lang == "python"
      assert length(code_block.lines) == 2
      assert Enum.at(code_block.lines, 0) == "def hello():"
      assert Enum.at(code_block.lines, 1) == "    print(\"Hello, World!\")"
    end

    test "code block with parameters" do
      source = """
      #+BEGIN_SRC emacs-lisp -n 10 :exports code
      (message "Hello")
      #+END_SRC
      """

      doc = Org.Parser.parse(source)
      [code_block] = Org.code_blocks(doc)

      assert code_block.lang == "emacs-lisp"
      assert code_block.details == "-n 10 :exports code"
      assert Enum.at(code_block.lines, 0) == "(message \"Hello\")"
    end

    test "code block without language" do
      source = """
      #+BEGIN_SRC
      Plain text
      #+END_SRC
      """

      doc = Org.Parser.parse(source)
      [code_block] = Org.code_blocks(doc)

      assert code_block.lang == ""
      assert code_block.details == ""
      assert Enum.at(code_block.lines, 0) == "Plain text"
    end
  end

  describe "comment parsing (official compatibility)" do
    test "line comments" do
      source = """
      # This is a comment
      #+TITLE: Document Title
      #+AUTHOR: John Doe
      """

      doc = Org.Parser.parse(source)

      assert length(doc.comments) == 3
      assert Enum.at(doc.comments, 0) == " This is a comment"
      assert Enum.at(doc.comments, 1) == "+TITLE: Document Title"
      assert Enum.at(doc.comments, 2) == "+AUTHOR: John Doe"
    end
  end

  describe "mixed content parsing (official compatibility)" do
    test "document with all elements" do
      source = """
      #+TITLE: Test Document
      #+AUTHOR: Test Author

      * Introduction
      This is a paragraph with some text.

      ** Features
      The features include:
      - Lists
      - Tables  
      - Code blocks

      | Feature | Status |
      |---------|--------|
      | Lists   | Done   |
      | Tables  | Done   |

      *** Code Example
      Here's some code:

      #+BEGIN_SRC elixir
      def hello(name) do
        IO.puts("Hello, " <> name <> "!")
      end
      #+END_SRC

      * Conclusion
      That's all folks!
      """

      doc = Org.Parser.parse(source)

      # Should parse without errors
      assert %Org.Document{} = doc

      # Check document metadata (file properties)
      assert doc.file_properties["TITLE"] == "Test Document"
      assert doc.file_properties["AUTHOR"] == "Test Author"

      # Check sections
      assert length(doc.sections) == 2
      intro_section = Enum.at(doc.sections, 0)
      assert intro_section.title == "Introduction"

      # Check nested structure
      assert length(intro_section.children) == 1
      features_section = Enum.at(intro_section.children, 0)
      assert features_section.title == "Features"

      # Check that content is properly attached
      lists = Org.lists(features_section)
      tables = Org.tables(features_section)
      code_blocks = Org.code_blocks(features_section.children |> Enum.at(0))

      assert length(lists) == 1
      assert length(tables) == 1
      assert length(code_blocks) == 1
    end
  end

  describe "edge cases (official compatibility)" do
    test "empty lines and whitespace handling" do
      source = """
      * Section 1


      Some content with empty lines.


      * Section 2

      More content.
      """

      doc = Org.Parser.parse(source)

      assert length(doc.sections) == 2
      assert Enum.at(doc.sections, 0).title == "Section 1"
      assert Enum.at(doc.sections, 1).title == "Section 2"
    end

    test "indented content" do
      source = """
      * Section
        This paragraph is indented.
        
          This line is more indented.
      """

      doc = Org.Parser.parse(source)

      section = Enum.at(doc.sections, 0)
      paragraphs = Org.paragraphs(section)

      # Should handle indented content gracefully
      assert length(paragraphs) > 0
    end
  end
end
