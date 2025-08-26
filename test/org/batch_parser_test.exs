defmodule Org.BatchParserTest do
  use ExUnit.Case

  alias Org.BatchParser
  alias Org.BatchParser.{DependencyGraph, FileEntry, Workspace}

  # Helper function for tests to flatten sections
  defp flatten_all_sections(section) do
    [section | Enum.flat_map(section.children, &flatten_all_sections/1)]
  end

  describe "batch parser basic functionality" do
    test "can create test org files and parse them" do
      # Create a temporary directory for testing
      test_dir = System.tmp_dir!() |> Path.join("org_batch_test_#{System.unique_integer()}")
      File.mkdir_p!(test_dir)

      # Create test org files
      file1_content = """
      #+TITLE: Project Overview
      #+AUTHOR: John Doe
      #+FILETAGS: :project:management:

      * TODO [#A] Complete project setup
      SCHEDULED: <2024-12-01 Mon>
      This is an important task.

      ** TODO Research phase
      DEADLINE: <2024-11-30 Sat>
      - Task 1
      - Task 2

      * DONE Initial planning
      CLOSED: [2024-11-15 Fri 14:30]
      Planning is complete.
      """

      file2_content = """
      #+TITLE: Technical Specifications
      #+AUTHOR: Jane Smith
      #+FILETAGS: :technical:specs:

      * TODO [#B] Database design
      This needs to be done before development.

      See also [[file:overview.org][Project Overview]].

      * TODO API endpoints
      - GET /users
      - POST /users
      """

      file1_path = Path.join(test_dir, "overview.org")
      file2_path = Path.join(test_dir, "specs.org")
      File.write!(file1_path, file1_content)
      File.write!(file2_path, file2_content)

      # Parse the directory
      {:ok, workspace} = BatchParser.parse_directory(test_dir)

      # Verify basic structure
      assert %Workspace{} = workspace
      assert workspace.root_path == test_dir
      assert length(workspace.file_entries) == 2

      # Check file entries
      overview_file = Enum.find(workspace.file_entries, &(&1.filename == "overview.org"))
      specs_file = Enum.find(workspace.file_entries, &(&1.filename == "specs.org"))

      assert overview_file != nil
      assert specs_file != nil

      # Check file properties
      assert FileEntry.title(overview_file) == "Project Overview"
      assert FileEntry.author(overview_file) == "John Doe"
      assert FileEntry.title(specs_file) == "Technical Specifications"
      assert FileEntry.author(specs_file) == "Jane Smith"

      # Check that parsed documents are available for external processing
      documents = Enum.map(workspace.file_entries, & &1.document)
      assert length(documents) == 2

      # External libraries can traverse documents to find TODO items
      todo_sections =
        documents
        |> Enum.flat_map(& &1.sections)
        |> Enum.flat_map(&flatten_all_sections/1)
        |> Enum.filter(&(&1.todo_keyword == "TODO"))

      assert length(todo_sections) >= 3

      # External libraries can find high priority items
      high_priority_sections =
        documents
        |> Enum.flat_map(& &1.sections)
        |> Enum.flat_map(&flatten_all_sections/1)
        |> Enum.filter(&(&1.priority == "A"))

      assert length(high_priority_sections) >= 1

      # Check file-level tags are available
      project_files =
        Enum.filter(workspace.file_entries, fn entry ->
          "project" in entry.tags
        end)

      assert length(project_files) >= 1

      # Test dependency graph
      graph = BatchParser.dependency_graph(workspace)
      assert %DependencyGraph{} = graph
      assert MapSet.size(graph.nodes) == 2

      # The specs.org file should link to overview.org
      outgoing = DependencyGraph.outgoing_links(graph, "specs.org")
      assert "overview.org" in outgoing

      # Clean up
      File.rm_rf!(test_dir)
    end

    test "handles empty directory" do
      test_dir = System.tmp_dir!() |> Path.join("empty_org_test_#{System.unique_integer()}")
      File.mkdir_p!(test_dir)

      {:ok, workspace} = BatchParser.parse_directory(test_dir)

      assert workspace.file_entries == []
      assert workspace.root_path == test_dir

      File.rm_rf!(test_dir)
    end

    test "filters files by extension" do
      test_dir = System.tmp_dir!() |> Path.join("filter_test_#{System.unique_integer()}")
      File.mkdir_p!(test_dir)

      # Create files with different extensions
      File.write!(Path.join(test_dir, "test.org"), "* Test Section")
      File.write!(Path.join(test_dir, "readme.txt"), "This is not an org file")
      File.write!(Path.join(test_dir, "notes.md"), "# Markdown file")

      {:ok, workspace} = BatchParser.parse_directory(test_dir, extensions: [".org"])

      assert length(workspace.file_entries) == 1
      assert hd(workspace.file_entries).filename == "test.org"

      File.rm_rf!(test_dir)
    end
  end

  describe "document access functionality" do
    test "external libraries can traverse parsed documents" do
      content1 = """
      * TODO [#A] High priority task
      This is important.

      ** TODO Subtask
      """

      content2 = """
      * DONE Completed task
      This is done.
      """

      {:ok, workspace} =
        BatchParser.parse_content([
          %{name: "work.org", content: content1},
          %{name: "personal.org", content: content2}
        ])

      # External libraries access documents directly
      documents = Enum.map(workspace.file_entries, & &1.document)
      assert length(documents) == 2

      # External filtering examples - how agenda libraries would work
      all_sections =
        documents
        |> Enum.flat_map(& &1.sections)
        |> Enum.flat_map(&flatten_all_sections/1)

      todo_sections = Enum.filter(all_sections, &(&1.todo_keyword == "TODO"))
      assert length(todo_sections) == 2

      high_priority_sections = Enum.filter(all_sections, &(&1.priority == "A"))
      assert length(high_priority_sections) == 1
      assert hd(high_priority_sections).title == "High priority task"

      done_sections = Enum.filter(all_sections, &(&1.todo_keyword == "DONE"))
      assert length(done_sections) == 1
    end
  end

  describe "content parsing functionality" do
    test "parse_content with strings" do
      content_list = [
        "* TODO [#A] Task from string 1\nThis is content",
        "* DONE Task from string 2\nCompleted task"
      ]

      {:ok, workspace} = BatchParser.parse_content(content_list)

      assert length(workspace.file_entries) == 2

      # Check file names were generated
      filenames = Enum.map(workspace.file_entries, & &1.filename)
      assert "content_1.org" in filenames
      assert "content_2.org" in filenames

      # Check that external libraries can find TODO items
      documents = Enum.map(workspace.file_entries, & &1.document)
      all_sections = documents |> Enum.flat_map(& &1.sections) |> Enum.flat_map(&flatten_all_sections/1)

      todo_sections = Enum.filter(all_sections, &(&1.todo_keyword == "TODO"))
      assert length(todo_sections) == 1

      high_priority_sections = Enum.filter(all_sections, &(&1.priority == "A"))
      assert length(high_priority_sections) == 1
    end

    test "parse_content with maps" do
      content_list = [
        %{name: "project.org", content: "* TODO Project task\nProject content"},
        %{name: "notes.org", content: "* Some notes\nNote content"},
        # No name provided
        %{content: "* TODO Unnamed task"}
      ]

      {:ok, workspace} = BatchParser.parse_content(content_list)

      assert length(workspace.file_entries) == 3

      # Check named files
      project_file = Enum.find(workspace.file_entries, &(&1.filename == "project.org"))
      notes_file = Enum.find(workspace.file_entries, &(&1.filename == "notes.org"))
      assert project_file != nil
      assert notes_file != nil

      # Check unnamed file got generated name
      unnamed_files = Enum.filter(workspace.file_entries, &String.starts_with?(&1.filename, "content_"))
      assert length(unnamed_files) == 1
    end

    test "parse_content with tuples" do
      content_list = [
        {"ideas.org", "* TODO New idea\nExplore this"},
        {"tasks.org", "* TODO [#A] Important task\nVery important"}
      ]

      {:ok, workspace} = BatchParser.parse_content(content_list)

      assert length(workspace.file_entries) == 2

      ideas_file = Enum.find(workspace.file_entries, &(&1.filename == "ideas.org"))
      tasks_file = Enum.find(workspace.file_entries, &(&1.filename == "tasks.org"))

      assert ideas_file != nil
      assert tasks_file != nil

      # Check that external libraries can find high priority items
      documents = Enum.map(workspace.file_entries, & &1.document)
      all_sections = documents |> Enum.flat_map(& &1.sections) |> Enum.flat_map(&flatten_all_sections/1)
      high_priority_sections = Enum.filter(all_sections, &(&1.priority == "A"))
      assert length(high_priority_sections) == 1
    end

    test "parse_documents with Org.Document structs" do
      doc1 = Org.load_string("* TODO Task from doc 1")
      doc2 = Org.load_string("* DONE Task from doc 2")

      {:ok, workspace} = BatchParser.parse_documents([doc1, doc2])

      assert length(workspace.file_entries) == 2

      # Check generated names
      filenames = Enum.map(workspace.file_entries, & &1.filename)
      assert "document_1.org" in filenames
      assert "document_2.org" in filenames

      # Check that external libraries can access the parsed documents
      documents = Enum.map(workspace.file_entries, & &1.document)
      assert length(documents) == 2
    end

    test "parse_documents with named document tuples" do
      doc1 = Org.load_string("* TODO Project task")
      doc2 = Org.load_string("* DONE Completed task")

      {:ok, workspace} =
        BatchParser.parse_documents([
          {"project.org", doc1},
          {"completed.org", doc2}
        ])

      assert length(workspace.file_entries) == 2

      project_file = Enum.find(workspace.file_entries, &(&1.filename == "project.org"))
      completed_file = Enum.find(workspace.file_entries, &(&1.filename == "completed.org"))

      assert project_file != nil
      assert completed_file != nil
      assert project_file.document == doc1
      assert completed_file.document == doc2
    end

    test "parse_content with file properties and tags" do
      content_with_props = """
      #+TITLE: Test Project
      #+AUTHOR: Test User
      #+FILETAGS: :test:project:

      * TODO [#B] Task with properties
      This task inherits file-level tags.
      """

      {:ok, workspace} =
        BatchParser.parse_content([
          %{name: "test.org", content: content_with_props}
        ])

      assert length(workspace.file_entries) == 1
      file_entry = hd(workspace.file_entries)

      # Check file properties
      assert FileEntry.title(file_entry) == "Test Project"
      assert FileEntry.author(file_entry) == "Test User"

      # Check file-level tags are available to external libraries
      assert "test" in file_entry.tags
      assert "project" in file_entry.tags

      # External libraries can find sections with these file-level tags
      documents = [file_entry.document]
      all_sections = documents |> Enum.flat_map(& &1.sections) |> Enum.flat_map(&flatten_all_sections/1)
      todo_sections = Enum.filter(all_sections, &(&1.todo_keyword == "TODO"))
      assert length(todo_sections) == 1
    end
  end

  describe "dependency graph functionality" do
    test "builds dependency graph from links" do
      file_entries = [
        %FileEntry{
          filename: "main.org",
          path: "/tmp/main.org",
          links: [
            %{url: "file:specs.org", description: "Technical Specs"},
            %{url: "notes.org", description: nil}
          ]
        },
        %FileEntry{
          filename: "specs.org",
          path: "/tmp/specs.org",
          links: [
            %{url: "file:notes.org", description: "Notes"}
          ]
        },
        %FileEntry{
          filename: "notes.org",
          path: "/tmp/notes.org",
          links: []
        }
      ]

      graph = DependencyGraph.build(file_entries)

      assert MapSet.size(graph.nodes) == 3
      assert length(graph.edges) == 3

      # Check specific relationships
      assert "specs.org" in DependencyGraph.outgoing_links(graph, "main.org")
      assert "notes.org" in DependencyGraph.outgoing_links(graph, "main.org")
      assert "notes.org" in DependencyGraph.outgoing_links(graph, "specs.org")

      # Check reverse relationships
      assert "main.org" in DependencyGraph.incoming_links(graph, "specs.org")
      assert "main.org" in DependencyGraph.incoming_links(graph, "notes.org")
      assert "specs.org" in DependencyGraph.incoming_links(graph, "notes.org")

      # Check for orphaned files
      orphans = DependencyGraph.orphaned_files(graph)
      # No orphans in this graph
      assert orphans == []
    end
  end
end
