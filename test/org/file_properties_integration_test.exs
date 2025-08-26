defmodule Org.FilePropertiesIntegrationTest do
  use ExUnit.Case

  describe "file properties integration with parser" do
    test "parses file properties from complete document" do
      content = """
      #+TITLE: My Test Document
      #+AUTHOR: John Doe
      #+EMAIL: john@example.com
      #+FILETAGS: :project:important:
      #+DATE: 2024-01-15

      * First Section
        Some content here.

      * Second Section
        More content.
      """

      doc = Org.load_string(content)

      # Verify file properties are parsed
      assert doc.file_properties["TITLE"] == "My Test Document"
      assert doc.file_properties["AUTHOR"] == "John Doe"
      assert doc.file_properties["EMAIL"] == "john@example.com"
      assert doc.file_properties["FILETAGS"] == ":project:important:"
      assert doc.file_properties["DATE"] == "2024-01-15"

      # Verify document structure is still parsed correctly
      assert length(doc.sections) == 2
      assert hd(doc.sections).title == "First Section"
      assert Enum.at(doc.sections, 1).title == "Second Section"
    end

    test "handles document with file properties only" do
      content = """
      #+TITLE: Properties Only
      #+AUTHOR: Jane Smith
      """

      doc = Org.load_string(content)

      assert doc.file_properties["TITLE"] == "Properties Only"
      assert doc.file_properties["AUTHOR"] == "Jane Smith"
      assert doc.sections == []
      assert doc.contents == []
    end

    test "handles document without file properties" do
      content = """
      * Section Without Properties
        Content here.
      """

      doc = Org.load_string(content)

      assert doc.file_properties == %{}
      assert length(doc.sections) == 1
      assert hd(doc.sections).title == "Section Without Properties"
    end

    test "distinguishes file properties from regular comments" do
      content = """
      #+TITLE: My Document
      #+AUTHOR: John Doe

      # This is a regular comment
      #+COMMENT: This is also a comment

      * Section
        Content
      """

      doc = Org.load_string(content)

      # File properties should be parsed
      assert doc.file_properties["TITLE"] == "My Document"
      assert doc.file_properties["AUTHOR"] == "John Doe"

      # Regular comments should be preserved
      assert " This is a regular comment" in doc.comments
      assert "+COMMENT: This is also a comment" in doc.comments
    end

    test "stops parsing file properties at first non-property content" do
      content = """
      #+TITLE: My Document
      #+AUTHOR: John Doe

      Some regular content here.

      #+DATE: 2024-01-15

      * Section
      """

      doc = Org.load_string(content)

      # Only properties before content should be parsed
      assert doc.file_properties["TITLE"] == "My Document"
      assert doc.file_properties["AUTHOR"] == "John Doe"
      assert Map.has_key?(doc.file_properties, "DATE") == false

      # The DATE line should be treated as regular content/comment
      assert "+DATE: 2024-01-15" in doc.comments
    end

    test "handles empty lines between file properties" do
      content = """
      #+TITLE: My Document

      #+AUTHOR: John Doe


      #+EMAIL: john@example.com

      * Section
      """

      doc = Org.load_string(content)

      assert doc.file_properties["TITLE"] == "My Document"
      assert doc.file_properties["AUTHOR"] == "John Doe"
      assert doc.file_properties["EMAIL"] == "john@example.com"
    end

    test "file properties work with complex document structure" do
      content = """
      #+TITLE: Complex Document
      #+AUTHOR: Alice Smith
      #+FILETAGS: :research:draft:

      * TODO [#A] Important Task
        :PROPERTIES:
        :ID: task-001
        :END:
        SCHEDULED: <2024-01-15 Mon>
        
        Task description here.

      ** DONE [#B] Subtask
         Subtask completed.

      * Regular Section
        | Column 1 | Column 2 |
        |----------|----------|
        | Data 1   | Data 2   |

        #+BEGIN_SRC python
        print("Hello World")
        #+END_SRC
      """

      doc = Org.load_string(content)

      # Verify file properties
      assert doc.file_properties["TITLE"] == "Complex Document"
      assert doc.file_properties["AUTHOR"] == "Alice Smith"
      assert doc.file_properties["FILETAGS"] == ":research:draft:"

      # Verify document structure
      assert length(doc.sections) == 2

      first_section = hd(doc.sections)
      assert first_section.title == "Important Task"
      assert first_section.todo_keyword == "TODO"
      assert first_section.priority == "A"
      assert first_section.properties["ID"] == "task-001"

      # Verify nested section
      assert length(first_section.children) == 1
      subtask = hd(first_section.children)
      assert subtask.title == "Subtask"
      assert subtask.todo_keyword == "DONE"
      assert subtask.priority == "B"
    end

    test "file properties with structured extraction" do
      content = """
      #+TITLE: Research Project
      #+AUTHOR: Dr. Jane Smith
      #+EMAIL: jane.smith@university.edu
      #+FILETAGS: :research:ai:ml:
      #+DATE: 2024-01-15
      #+LANGUAGE: en
      #+DESCRIPTION: A comprehensive study on machine learning applications

      * Introduction
      """

      doc = Org.load_string(content)
      structured = Org.FileProperties.extract_structured_properties(doc.file_properties)

      assert structured.title == "Research Project"
      assert structured.author == "Dr. Jane Smith"
      assert structured.email == "jane.smith@university.edu"
      assert structured.tags == ["research", "ai", "ml"]
      assert structured.date == "2024-01-15"
      assert structured.language == "en"
      assert structured.description == "A comprehensive study on machine learning applications"
    end

    test "fragment parser preserves file properties context" do
      # Test that fragment parsing doesn't interfere with file properties
      full_content = """
      #+TITLE: Fragment Test
      #+AUTHOR: Test User

      * Section 1
        Content here.

      * Section 2
        More content.
      """

      doc = Org.load_string(full_content)

      # Parse a fragment
      fragment = Org.parse_fragment("** New Subsection", type: :section)

      # Original document properties should be preserved
      assert doc.file_properties["TITLE"] == "Fragment Test"
      assert doc.file_properties["AUTHOR"] == "Test User"

      # Fragment parsing should work independently
      assert fragment.content.title == "New Subsection"
    end
  end

  describe "JSON serialization with file properties" do
    test "file properties are included in JSON output" do
      content = """
      #+TITLE: JSON Test
      #+AUTHOR: Test Author
      #+FILETAGS: :json:test:

      * Section
      """

      doc = Org.load_string(content)
      json_map = Org.to_json_map(doc)

      assert json_map.file_properties["TITLE"] == "JSON Test"
      assert json_map.file_properties["AUTHOR"] == "Test Author"
      assert json_map.file_properties["FILETAGS"] == ":json:test:"
    end
  end
end
