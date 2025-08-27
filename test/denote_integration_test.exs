defmodule DenoteIntegrationTest do
  use ExUnit.Case, async: true

  alias Org.Parser
  alias Org.Parser.Registry
  alias Org.Plugins.Denote

  setup do
    Registry.start()
    Registry.register_plugin(Denote, [])
    :ok
  end

  describe "Denote file parsing integration" do
    test "parses document with Denote links" do
      content = """
      #+TITLE: My Research Note
      #+FILETAGS: :research:ai:

      * Introduction
      This document references [[denote:20240115T144532][another note]] and 
      also links to [[id:20240116T093021][a different note]].

      * Related Work
      See also [[denote:20240117T081522]] for more details.
      """

      doc = Parser.parse(content)

      # Check that the document was parsed
      assert doc.file_properties["TITLE"] == "My Research Note"
      assert doc.file_properties["FILETAGS"] == ":research:ai:"

      # The sections should contain the parsed content
      assert length(doc.sections) == 2
    end

    test "parses Denote dynamic blocks" do
      content = """
      #+TITLE: Note with Dynamic Blocks

      * Backlinks
      #+BEGIN: denote-backlinks
      #+END:

      * Related Notes  
      #+BEGIN: denote-related :limit 5 :sort date
      #+END:

      * Links
      #+BEGIN: denote-links :filter research
      #+END:
      """

      doc = Parser.parse(content)
      assert doc.file_properties["TITLE"] == "Note with Dynamic Blocks"
      assert length(doc.sections) == 3
    end

    test "handles mixed Denote and regular org content" do
      content = """
      #+TITLE: Mixed Content

      * Tasks
      ** TODO Research [[denote:20240115T144532][AI papers]]
         SCHEDULED: <2024-01-20>
         :PROPERTIES:
         :ID: unique-id-123
         :END:
         
      ** DONE Review [[id:20240116T093021][ML frameworks]]
         CLOSED: [2024-01-19 Fri 14:30]
         
      * Notes
      Regular paragraph with a [[https://example.com][web link]] and
      a denote link [[denote:20240117T081522][to another note]].

      #+BEGIN: denote-backlinks
      #+END:
      """

      doc = Parser.parse(content)
      assert doc.file_properties["TITLE"] == "Mixed Content"

      # Check sections were parsed
      assert length(doc.sections) == 2

      # First section should have child sections (tasks)
      [tasks_section | _] = doc.sections
      assert length(tasks_section.children) == 2

      # Check TODO states
      [todo_task, done_task] = tasks_section.children
      assert todo_task.todo_keyword == "TODO"
      assert done_task.todo_keyword == "DONE"
    end

    test "filename metadata extraction" do
      # Test the standalone function
      {:ok, id} = Denote.extract_denote_id("20240115T144532--my-research-note__ai_ml.org")
      assert id == "20240115T144532"

      filename = Denote.generate_filename("Test Note", ["tag1", "tag2"])
      assert Regex.match?(~r/^\d{8}T\d{6}--test-note__tag1_tag2\.org$/, filename)
    end

    test "parses document with multiple Denote link types" do
      content = """
      * Links Collection
      - Denote link: [[denote:20240115T144532][Note 1]]
      - ID link: [[id:20240116T093021][Note 2]]
      - Plain denote: [[denote:20240117T081522]]
      - Regular link: [[file:./notes/other.org][Other file]]
      """

      doc = Parser.parse(content)
      assert length(doc.sections) == 1
    end
  end

  describe "edge cases" do
    test "handles malformed Denote links gracefully" do
      content = """
      * Invalid Links
      - [[denote:invalid-id][Description]]
      - [[denote:20240115T144532
      - [[id:][Empty ID]]
      - [[denote:]]
      """

      # Should still parse the document, even with invalid links
      doc = Parser.parse(content)
      assert length(doc.sections) == 1
    end

    test "handles empty dynamic blocks" do
      content = """
      #+BEGIN: denote-backlinks
      #+END:

      #+BEGIN: denote-links
      #+END:
      """

      doc = Parser.parse(content)
      assert doc != nil
    end

    test "parses complex nested structure with Denote elements" do
      content = """
      * Parent Section
      ** Child with [[denote:20240115T144532][denote link]]
      *** Grandchild
          :PROPERTIES:
          :CUSTOM_ID: test-id
          :END:
          
          Content with [[id:20240116T093021][ID link]].
          
          #+BEGIN: denote-related :sort title
          #+END:
          
      ** Another Child
         - List item with [[denote:20240117T081522]]
         - Another item
      """

      doc = Parser.parse(content)
      assert length(doc.sections) == 1

      [parent] = doc.sections
      assert length(parent.children) == 2
    end
  end
end
