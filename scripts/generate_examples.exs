#!/usr/bin/env elixir
# credo:disable-for-this-file

# Example Generator for Elixir Org Parser
# This script generates comprehensive examples demonstrating all features
# Usage: mix run example/generate_examples.exs

defmodule ExampleGenerator do
  @moduledoc """
  Generates comprehensive examples for the Elixir Org parser demonstrating:
  - Basic parsing and reading
  - JSON serialization
  - Write operations (adding, updating, removing nodes)
  - Node finding and navigation
  - Round-trip operations (parse -> modify -> serialize)
  """

  def main do
    IO.puts("🚀 Generating Elixir Org Parser Examples...")
    IO.puts("=" <> String.duplicate("=", 50))

    # Ensure example directories exist
    File.mkdir_p!("example/basic_parsing")
    File.mkdir_p!("example/json_serialization")
    File.mkdir_p!("example/write_operations")
    File.mkdir_p!("example/node_finding")
    File.mkdir_p!("example/comprehensive_workflow")
    File.mkdir_p!("example/real_world_examples")

    # Generate all examples
    generate_basic_parsing_example()
    generate_json_serialization_example()
    generate_write_operations_example()
    generate_node_finding_example()
    generate_comprehensive_example()
    generate_real_world_example()

    IO.puts("\n✅ All examples generated successfully!")
    IO.puts("📂 Check the example/ subdirectories for all files.")
  end

  def generate_basic_parsing_example do
    IO.puts("\n1️⃣  Generating basic parsing example...")

    example_content = """
    # Basic Org Mode Parsing Example

    This example demonstrates basic parsing of org-mode documents.

    ```elixir
    # Parse a simple org document
    source = \"\"\"
    #+TITLE: My Project
    #+AUTHOR: Developer

    * TODO [#A] Important Task
    This task has high priority and needs immediate attention.

    ** DONE [#B] Completed Subtask
    This subtask was completed successfully.

    ** TODO [#C] Pending Subtask
    This still needs to be done.

    * Resources
    Here are some useful resources:

    - [[https://elixir-lang.org][Elixir Documentation]]
    - *Important* information about /functional programming/
    - =Code examples= and ~verbatim text~

    | Feature | Status | Priority |
    |---------|--------|----------|
    | Parser  | Done   | High     |
    | Writer  | Done   | High     |
    | JSON    | Done   | Medium   |

    #+BEGIN_SRC elixir
    defmodule Example do
      def hello(name) do
        "Hello, \#{name}!"
      end
    end
    #+END_SRC
    \"\"\"

    # Parse the document
    doc = Org.Parser.parse(source)

    # Access document properties
    IO.inspect(doc.comments, label: "Comments")
    IO.inspect(length(doc.sections), label: "Number of sections")

    # Find specific sections
    main_task = Org.section(doc, ["Important Task"])
    IO.inspect(main_task.todo_keyword, label: "Main task TODO")
    IO.inspect(main_task.priority, label: "Main task priority")

    # Extract all TODO items
    todos = Org.todo_items(doc)
    IO.puts("TODO items found: \#{length(todos)}")
    for todo <- todos do
      IO.puts("- \#{todo.todo_keyword} [\#{todo.priority || "None"}] \#{todo.title}")
    end

    # Extract content by type
    tables = Org.tables(doc)
    IO.puts("Tables found: \#{length(tables)}")

    code_blocks = Org.code_blocks(doc)
    IO.puts("Code blocks found: \#{length(code_blocks)}")

    paragraphs = Org.paragraphs(doc)
    IO.puts("Paragraphs found: \#{length(paragraphs)}")

    lists = Org.lists(doc)
    IO.puts("Lists found: \#{length(lists)}")
    ```

    ## Output:
    ```
    Comments: ["+TITLE: My Project", "+AUTHOR: Developer"]
    Number of sections: 2
    Main task TODO: "TODO"
    Main task priority: "A"
    TODO items found: 2
    - TODO [A] Important Task
    - TODO [C] Pending Subtask
    Tables found: 1
    Code blocks found: 1
    Paragraphs found: 3
    Lists found: 1
    ```
    """

    File.write!("example/basic_parsing/README.md", example_content)
  end

  def generate_json_serialization_example do
    IO.puts("2️⃣  Generating JSON serialization example...")

    # Create a sample document
    source = """
    * TODO [#A] Project Setup
    Initial project configuration and setup.

    ** DONE Environment Setup
    Development environment is ready.

    | Task | Status | Time |
    |------|--------|------|
    | Git  | Done   | 1h   |
    | IDE  | Done   | 30m  |

    #+BEGIN_SRC bash
    mix new my_project
    cd my_project
    #+END_SRC
    """

    doc = Org.Parser.parse(source)
    json_map = Org.to_json_map(doc)

    # Pretty print JSON structure
    json_content = inspect(json_map, pretty: true, limit: :infinity)

    example_content = """
    # JSON Serialization Example

    This example shows how to convert org-mode documents to JSON format.

    ## Original Org Content:
    ```org
    #{String.trim(source)}
    ```

    ## Elixir Code:
    ```elixir
    # Parse the document
    doc = Org.Parser.parse(source)

    # Convert to JSON-encodable map
    json_map = Org.to_json_map(doc)

    # Alternative using encoder module
    json_map2 = Org.encode_json(doc)

    # Both methods produce the same result
    assert json_map == json_map2

    # The JSON map can be encoded with any JSON library
    # For example with Jason: Jason.encode!(json_map)
    ```

    ## Generated JSON Structure:
    ```elixir
    #{json_content}
    ```

    ## Key Features:
    - Every struct has a `type` field for easy identification
    - All nested structures are properly serialized
    - Formatted text maintains span information
    - Links preserve URL and description
    - Tables include both data rows and separators
    - Code blocks maintain language and content
    - TODO keywords and priorities are preserved
    """

    File.write!("example/json_serialization/README.md", example_content)
    File.write!("example/json_serialization/sample_data.json", json_content)
  end

  def generate_write_operations_example do
    IO.puts("3️⃣  Generating write operations example...")

    example_content = """
    # Write Operations Example

    This example demonstrates all write operations available in the parser.

    ```elixir
    # Start with a basic document
    doc = Org.Parser.parse("* Project\\nBasic project structure.")

    # 1. ADD OPERATIONS

    # Add a new section at root level
    doc = Org.add_section(doc, [], "Resources", "TODO", "B")

    # Add a child section
    doc = Org.add_section(doc, ["Project"], "Development", "TODO", "A")
    doc = Org.add_section(doc, ["Project"], "Testing", "TODO", "B")

    # Add content to sections
    dev_para = %Org.Paragraph{lines: ["Development tasks and milestones."]}
    doc = Org.add_content(doc, ["Project", "Development"], dev_para)

    # Add a code block
    code = %Org.CodeBlock{
      lang: "elixir",
      details: "",
      lines: ["defmodule MyApp do", "  # Application code", "end"]
    }
    doc = Org.add_content(doc, ["Project", "Development"], code)

    # Add a table
    table = %Org.Table{
      rows: [
        %Org.Table.Row{cells: ["Task", "Status", "Assignee"]},
        %Org.Table.Separator{},
        %Org.Table.Row{cells: ["Setup", "Done", "Alice"]},
        %Org.Table.Row{cells: ["Testing", "In Progress", "Bob"]}
      ]
    }
    doc = Org.add_content(doc, ["Project", "Testing"], table)

    # Add a list
    list = %Org.List{
      items: [
        %Org.List.Item{content: "Unit tests", indent: 0, ordered: false, children: []},
        %Org.List.Item{content: "Integration tests", indent: 0, ordered: false, children: []},
        %Org.List.Item{content: "Performance tests", indent: 0, ordered: false, children: []}
      ]
    }
    doc = Org.add_content(doc, ["Resources"], list)

    # 2. INSERT OPERATIONS (at specific positions)

    # Insert at first position
    doc = Org.Writer.insert_section(doc, ["Project"], :first, "Planning", "TODO", "A")

    # Insert before a specific section
    doc = Org.Writer.insert_section(doc, ["Project"], {:before, "Testing"}, "Implementation", "TODO", "A")

    # Insert after a specific section
    doc = Org.Writer.insert_section(doc, ["Project"], {:after, "Development"}, "Documentation", "TODO", "C")

    # 3. UPDATE OPERATIONS

    # Update section properties
    doc = Org.update_node(doc, ["Project", "Planning"], fn section ->
      %{section |
        todo_keyword: "DONE",
        priority: "A"
      }
    end)

    # Update section title
    doc = Org.update_node(doc, ["Resources"], fn section ->
      %{section | title: "Project Resources"}
    end)

    # 4. MOVE OPERATIONS

    # Move a section to a different parent
    doc = Org.move_node(doc, ["Project", "Documentation"], ["Project Resources"])

    # 5. REMOVE OPERATIONS

    # Remove a section (this would remove Implementation)
    # doc = Org.remove_node(doc, ["Project", "Implementation"])

    # Serialize back to org format
    result = Org.to_org_string(doc)
    IO.puts(result)
    ```

    ## Expected Output:
    ```org
    * Project
    Basic project structure.

    ** DONE [#A] Planning
    ** TODO [#A] Development
    Development tasks and milestones.

    #+BEGIN_SRC elixir
    defmodule MyApp do
      # Application code
    end
    #+END_SRC

    ** TODO [#A] Implementation
    ** TODO [#B] Testing
    | Task | Status | Assignee |
    |----------|
    | Setup | Done | Alice |
    | Testing | In Progress | Bob |

    * Project Resources
    - Unit tests
    - Integration tests
    - Performance tests

    ** TODO [#C] Documentation
    ```

    ## Available Write Operations:

    ### Adding Content
    - `Org.add_section/5` - Add section at end of children
    - `Org.add_content/3` - Add content to section or document

    ### Inserting Content
    - `Org.Writer.insert_section/6` - Insert at specific position
      - `:first` - At beginning
      - `:last` - At end (same as add)
      - `{:before, title}` - Before specific sibling
      - `{:after, title}` - After specific sibling
      - `index` - At numeric position

    ### Modifying Content
    - `Org.update_node/3` - Update using function
    - `Org.move_node/3` - Move to different location
    - `Org.remove_node/2` - Remove from document

    ### Serialization
    - `Org.to_org_string/1` - Convert back to org-mode text
    """

    File.write!("example/write_operations/README.md", example_content)
  end

  def generate_node_finding_example do
    IO.puts("4️⃣  Generating node finding example...")

    example_content = """
    # Node Finding and Navigation Example

    This example shows all the ways to find and navigate nodes in an org document.

    ```elixir
    # Create a sample document with complex structure
    source = \"\"\"
    * TODO [#A] Frontend Development
    User interface development tasks.

    ** TODO [#B] Components
    Reusable UI components.

    *** DONE Button Component
    Basic button with styling.

    *** TODO Modal Component
    Modal dialog implementation.

    ** TODO [#A] Pages
    Application pages and routing.

    *** TODO Home Page
    Landing page design.

    *** TODO Dashboard
    User dashboard interface.

    * DONE [#B] Backend Development
    Server-side development.

    ** DONE API Design
    RESTful API specification.

    ** TODO Database Schema
    Data model design.

    * Resources
    Development resources and links.
    \"\"\"

    doc = Org.Parser.parse(source)

    # 1. BASIC PATH FINDING

    # Find by exact path
    frontend = Org.find_node(doc, ["Frontend Development"])
    IO.puts("Found: \#{frontend.title}")

    # Find nested nodes
    button = Org.find_node(doc, ["Frontend Development", "Components", "Button Component"])
    IO.puts("Found: \#{button.title} - \#{button.todo_keyword}")

    # Find using NodeFinder directly
    modal = Org.NodeFinder.find_by_path(doc, ["Frontend Development", "Components", "Modal Component"])
    IO.puts("Found: \#{modal.title}")

    # 2. FINDING BY INDEX

    # Find first section
    first_section = Org.NodeFinder.find_by_path(doc, [{:section, 0}])
    IO.puts("First section: \#{first_section.title}")

    # Find second child of first section
    second_child = Org.NodeFinder.find_by_path(doc, ["Frontend Development", {:child, 1}])
    IO.puts("Second child: \#{second_child.title}")

    # 3. FINDING ALL NODES BY CRITERIA

    # Find all TODO items
    todo_items = Org.NodeFinder.find_all(doc, fn
      %Org.Section{todo_keyword: "TODO"} -> true
      _ -> false
    end)

    IO.puts("\\nTODO Items (\#{length(todo_items)}):")
    for todo <- todo_items do
      path = Org.NodeFinder.path_to_node(doc, todo)
      IO.puts("- [\#{todo.priority || "None"}] \#{Enum.join(path, " > ")}")
    end

    # Find all DONE items
    done_items = Org.NodeFinder.find_all(doc, fn
      %Org.Section{todo_keyword: "DONE"} -> true
      _ -> false
    end)

    IO.puts("\\nDONE Items (\#{length(done_items)}):")
    for done <- done_items do
      path = Org.NodeFinder.path_to_node(doc, done)
      IO.puts("- [\#{done.priority || "None"}] \#{Enum.join(path, " > ")}")
    end

    # Find all high priority items (A)
    high_priority = Org.NodeFinder.find_all(doc, fn
      %Org.Section{priority: "A"} -> true
      _ -> false
    end)

    IO.puts("\\nHigh Priority Items (\#{length(high_priority)}):")
    for item <- high_priority do
      IO.puts("- \#{item.todo_keyword} \#{item.title}")
    end

    # Find all leaf nodes (sections with no children)
    leaf_sections = Org.NodeFinder.find_all(doc, fn
      %Org.Section{children: []} -> true
      _ -> false
    end)

    IO.puts("\\nLeaf Sections (\#{length(leaf_sections)}):")
    for leaf <- leaf_sections do
      path = Org.NodeFinder.path_to_node(doc, leaf)
      IO.puts("- \#{Enum.join(path, " > ")}")
    end

    # 4. PARENT AND PATH OPERATIONS

    # Find parent of a node
    {parent, {type, index}} = Org.NodeFinder.find_parent(doc, button)
    IO.puts("\\nParent of 'Button Component': \#{parent.title} (at \#{type} \#{index})")

    # Generate path to node
    path_to_modal = Org.NodeFinder.path_to_node(doc, modal)
    IO.puts("Path to Modal Component: \#{Enum.join(path_to_modal, " > ")}")

    # 5. WALKING THE ENTIRE TREE

    IO.puts("\\nWalking entire document tree:")
    Org.NodeFinder.walk(doc, fn
      %Org.Document{}, path ->
        IO.puts("📄 Document (root)")

      %Org.Section{title: title, todo_keyword: todo}, path ->
        indent = String.duplicate("  ", length(path) - 1)
        todo_part = if todo, do: " [\#{todo}]", else: ""
        IO.puts("\#{indent}📁 \#{title}\#{todo_part}")

      %Org.Paragraph{lines: [first_line | _]}, path ->
        indent = String.duplicate("  ", length(path))
        preview = String.slice(to_string(first_line), 0..30)
        IO.puts("\#{indent}📝 Paragraph: \#{preview}...")

      content, path ->
        indent = String.duplicate("  ", length(path))
        type = content.__struct__ |> Module.split() |> List.last()
        IO.puts("\#{indent}📄 \#{type}")
    end)

    # 6. PRACTICAL SEARCH FUNCTIONS

    # Find sections containing specific text
    sections_with_text = Org.NodeFinder.find_all(doc, fn
      %Org.Section{title: title} -> String.contains?(String.downcase(title), "component")
      _ -> false
    end)

    IO.puts("\\nSections containing 'component' (\#{length(sections_with_text)}):")
    for section <- sections_with_text do
      IO.puts("- \#{section.title}")
    end

    # Find all paragraphs
    all_paragraphs = Org.NodeFinder.find_all(doc, fn
      %Org.Paragraph{} -> true
      _ -> false
    end)

    IO.puts("\\nTotal paragraphs found: \#{length(all_paragraphs)}")
    ```

    ## Expected Output:
    ```
    Found: Frontend Development
    Found: Button Component - DONE
    Found: Modal Component
    First section: Frontend Development
    Second child: Pages

    TODO Items (7):
    - [A] Frontend Development
    - [B] Components
    - [None] Modal Component
    - [A] Pages
    - [None] Home Page
    - [None] Dashboard
    - [None] Database Schema

    DONE Items (3):
    - [None] Button Component
    - [B] Backend Development
    - [None] API Design

    High Priority Items (2):
    - TODO Frontend Development
    - TODO Pages

    Leaf Sections (7):
    - Frontend Development > Components > Button Component
    - Frontend Development > Components > Modal Component
    - Frontend Development > Pages > Home Page
    - Frontend Development > Pages > Dashboard
    - Backend Development > API Design
    - Backend Development > Database Schema
    - Resources

    Parent of 'Button Component': Components (at :child 0)
    Path to Modal Component: Frontend Development > Components > Modal Component

    Walking entire document tree:
    📄 Document (root)
      📁 Frontend Development [TODO]
        📝 Paragraph: User interface development task...
        📁 Components [TODO]
          📝 Paragraph: Reusable UI components...
          📁 Button Component [DONE]
            📝 Paragraph: Basic button with styling...
          📁 Modal Component [TODO]
            📝 Paragraph: Modal dialog implementation...
        📁 Pages [TODO]
          📝 Paragraph: Application pages and routing...
          📁 Home Page [TODO]
            📝 Paragraph: Landing page design...
          📁 Dashboard [TODO]
            📝 Paragraph: User dashboard interface...
      📁 Backend Development [DONE]
        📝 Paragraph: Server-side development...
        📁 API Design [DONE]
          📝 Paragraph: RESTful API specification...
        📁 Database Schema [TODO]
          📝 Paragraph: Data model design...
      📁 Resources
        📝 Paragraph: Development resources and lin...

    Sections containing 'component' (3):
    - Components
    - Button Component
    - Modal Component

    Total paragraphs found: 10
    ```

    ## Node Finding Methods Summary:

    ### Direct Finding
    - `Org.find_node(doc, path)` - Find by path
    - `Org.NodeFinder.find_by_path(doc, path)` - Same as above
    - Path formats: `["Title1", "Title2"]` or `[{:section, 0}, {:child, 1}]`

    ### Search Operations
    - `Org.NodeFinder.find_all(doc, predicate_fn)` - Find all matching nodes
    - `Org.NodeFinder.find_parent(doc, node)` - Find parent and position
    - `Org.NodeFinder.path_to_node(doc, node)` - Get path to node

    ### Tree Navigation
    - `Org.NodeFinder.walk(doc, visitor_fn)` - Visit all nodes in tree
    - Visitor function receives `(node, path_from_root)`
    """

    File.write!("example/node_finding/README.md", example_content)
  end

  def generate_comprehensive_example do
    IO.puts("5️⃣  Generating comprehensive example...")

    # This will be a complete workflow example
    example_content = """
    # Comprehensive Workflow Example

    This example demonstrates a complete workflow combining parsing, modification,
    and serialization for a project management scenario.

    ```elixir
    defmodule ProjectManager do
      @doc "Creates a new project structure"
      def create_project(name, description) do
        # Start with basic structure
        doc_text = \"\"\"
        #+TITLE: \#{name}
        #+AUTHOR: Project Manager
        #+DATE: \#{Date.utc_today()}

        * Project Overview
        \#{description}

        * Status
        Project initialized and ready for development.
        \"\"\"

        Org.Parser.parse(doc_text)
      end

      @doc "Adds development phases to project"
      def add_development_phases(doc) do
        doc
        |> Org.add_section([], "Development Phases", "TODO", "A")
        |> Org.add_section(["Development Phases"], "Planning", "TODO", "A")
        |> Org.add_section(["Development Phases"], "Implementation", "TODO", "A")
        |> Org.add_section(["Development Phases"], "Testing", "TODO", "B")
        |> Org.add_section(["Development Phases"], "Deployment", "TODO", "B")
      end

      @doc "Adds tasks to each phase"
      def add_phase_tasks(doc) do
        # Planning tasks
        planning_tasks = %Org.List{
          items: [
            %Org.List.Item{content: "Requirements gathering", indent: 0, ordered: false, children: []},
            %Org.List.Item{content: "Architecture design", indent: 0, ordered: false, children: []},
            %Org.List.Item{content: "Technology selection", indent: 0, ordered: false, children: []},
            %Org.List.Item{content: "Timeline creation", indent: 0, ordered: false, children: []}
          ]
        }

        # Implementation tasks
        impl_tasks = %Org.List{
          items: [
            %Org.List.Item{content: "Core functionality", indent: 0, ordered: true, number: 1, children: []},
            %Org.List.Item{content: "User interface", indent: 0, ordered: true, number: 2, children: []},
            %Org.List.Item{content: "Integration points", indent: 0, ordered: true, number: 3, children: []},
            %Org.List.Item{content: "Error handling", indent: 0, ordered: true, number: 4, children: []}
          ]
        }

        # Add tasks to phases
        doc
        |> Org.add_content(["Development Phases", "Planning"], planning_tasks)
        |> Org.add_content(["Development Phases", "Implementation"], impl_tasks)
      end

      @doc "Adds project metrics table"
      def add_metrics_table(doc) do
        metrics_table = %Org.Table{
          rows: [
            %Org.Table.Row{cells: ["Metric", "Target", "Current", "Status"]},
            %Org.Table.Separator{},
            %Org.Table.Row{cells: ["Code Coverage", "90%", "0%", "Not Started"]},
            %Org.Table.Row{cells: ["Performance", "<100ms", "TBD", "Not Started"]},
            %Org.Table.Row{cells: ["Security Score", "A+", "TBD", "Not Started"]},
            %Org.Table.Row{cells: ["Documentation", "100%", "25%", "In Progress"]}
          ]
        }

        Org.add_content(doc, ["Status"], metrics_table)
      end

      @doc "Adds code snippets and examples"
      def add_code_examples(doc) do
        # Add a section for technical details
        doc = Org.add_section(doc, [], "Technical Details", nil, "C")

        # Add example code
        setup_code = %Org.CodeBlock{
          lang: "bash",
          details: "",
          lines: [
            "# Project setup",
            "mix new \#{String.downcase(String.replace("My Project", " ", "_"))}",
            "cd my_project",
            "mix deps.get",
            "mix test"
          ]
        }

        config_code = %Org.CodeBlock{
          lang: "elixir",
          details: "",
          lines: [
            "# Configuration example",
            "config :my_app,",
            "  env: Mix.env(),",
            "  port: 4000,",
            "  database_url: System.get_env(\\"DATABASE_URL\\")"
          ]
        }

        doc
        |> Org.add_content(["Technical Details"], setup_code)
        |> Org.add_content(["Technical Details"], config_code)
      end

      @doc "Simulates project progress updates"
      def update_project_progress(doc) do
        # Mark planning as complete
        doc = Org.update_node(doc, ["Development Phases", "Planning"], fn section ->
          %{section | todo_keyword: "DONE"}
        end)

        # Update metrics
        doc = Org.update_node(doc, ["Status"], fn section ->
          # Find and update the metrics table
          updated_contents = Enum.map(section.contents, fn
            %Org.Table{rows: rows} = table ->
              updated_rows = Enum.map(rows, fn
                %Org.Table.Row{cells: ["Code Coverage", target, _current, _status]} ->
                  %Org.Table.Row{cells: ["Code Coverage", target, "45%", "In Progress"]}
                %Org.Table.Row{cells: ["Documentation", target, _current, _status]} ->
                  %Org.Table.Row{cells: ["Documentation", target, "60%", "In Progress"]}
                row -> row
              end)
              %{table | rows: updated_rows}
            content -> content
          end)

          %{section | contents: updated_contents}
        end)

        # Add progress notes
        progress_note = %Org.Paragraph{
          lines: [
            %Org.FormattedText{
              spans: [
                "Progress update on ",
                %Org.FormattedText.Span{format: :bold, content: Date.to_string(Date.utc_today())},
                ": Planning phase completed successfully. Implementation is ",
                %Org.FormattedText.Span{format: :italic, content: "in progress"},
                " with good momentum."
              ]
            }
          ]
        }

        Org.add_content(doc, ["Status"], progress_note)
      end

      @doc "Generates project reports"
      def generate_reports(doc) do
        # Extract all TODO items
        todo_items = Org.NodeFinder.find_all(doc, fn
          %Org.Section{todo_keyword: "TODO"} -> true
          _ -> false
        end)

        # Extract all DONE items
        done_items = Org.NodeFinder.find_all(doc, fn
          %Org.Section{todo_keyword: "DONE"} -> true
          _ -> false
        end)

        # Generate summary
        summary = %Org.Table{
          rows: [
            %Org.Table.Row{cells: ["Category", "Count", "Percentage"]},
            %Org.Table.Separator{},
            %Org.Table.Row{cells: ["Completed", to_string(length(done_items)), "\#{round(length(done_items) / (length(done_items) + length(todo_items)) * 100)}%"]},
            %Org.Table.Row{cells: ["Remaining", to_string(length(todo_items)), "\#{round(length(todo_items) / (length(done_items) + length(todo_items)) * 100)}%"]},
            %Org.Table.Row{cells: ["Total Tasks", to_string(length(done_items) + length(todo_items)), "100%"]}
          ]
        }

        # Add reports section
        doc = Org.add_section(doc, [], "Project Reports", nil, "C")
        doc = Org.add_section(doc, ["Project Reports"], "Task Summary")
        Org.add_content(doc, ["Project Reports", "Task Summary"], summary)
      end

      @doc "Main workflow function"
      def run_complete_workflow do
        IO.puts("🚀 Running Complete Project Management Workflow\\n")

        # Step 1: Create project
        IO.puts("1. Creating new project...")
        doc = create_project("My Awesome App", "A revolutionary application that will change the world.")

        # Step 2: Add structure
        IO.puts("2. Adding development phases...")
        doc = add_development_phases(doc)

        # Step 3: Add tasks
        IO.puts("3. Adding phase tasks...")
        doc = add_phase_tasks(doc)

        # Step 4: Add metrics
        IO.puts("4. Adding project metrics...")
        doc = add_metrics_table(doc)

        # Step 5: Add technical details
        IO.puts("5. Adding code examples...")
        doc = add_code_examples(doc)

        # Step 6: Simulate progress
        IO.puts("6. Updating project progress...")
        doc = update_project_progress(doc)

        # Step 7: Generate reports
        IO.puts("7. Generating project reports...")
        doc = generate_reports(doc)

        # Step 8: Export in multiple formats
        IO.puts("8. Exporting project documentation...")

        # Export as org file
        org_content = Org.to_org_string(doc)
        File.write!("example/generated/complete_project.org", org_content)

        # Export as JSON
        json_content = Org.to_json_map(doc) |> inspect(pretty: true, limit: :infinity)
        File.write!("example/generated/complete_project.json", json_content)

        # Print summary
        IO.puts("\\n✅ Workflow completed successfully!")
        IO.puts("📊 Project Statistics:")

        # Count different elements
        sections = Org.NodeFinder.find_all(doc, fn %Org.Section{} -> true; _ -> false end)
        tables = Org.NodeFinder.find_all(doc, fn %Org.Table{} -> true; _ -> false end)
        code_blocks = Org.NodeFinder.find_all(doc, fn %Org.CodeBlock{} -> true; _ -> false end)
        lists = Org.NodeFinder.find_all(doc, fn %Org.List{} -> true; _ -> false end)
        paragraphs = Org.NodeFinder.find_all(doc, fn %Org.Paragraph{} -> true; _ -> false end)

        IO.puts("- Sections: \#{length(sections)}")
        IO.puts("- Tables: \#{length(tables)}")
        IO.puts("- Code Blocks: \#{length(code_blocks)}")
        IO.puts("- Lists: \#{length(lists)}")
        IO.puts("- Paragraphs: \#{length(paragraphs)}")

        IO.puts("\\n📁 Files generated:")
        IO.puts("- example/generated/complete_project.org")
        IO.puts("- example/generated/complete_project.json")

        doc
      end
    end

    # Run the complete workflow
    ProjectManager.run_complete_workflow()
    ```

    This comprehensive example shows how to:

    1. **Create** structured documents programmatically
    2. **Build** complex hierarchies with multiple content types
    3. **Update** content dynamically based on business logic
    4. **Generate** reports and summaries from document data
    5. **Export** to multiple formats (org-mode and JSON)
    6. **Track** project metrics and progress over time

    The workflow creates a complete project management document with:
    - Project metadata and description
    - Development phases with TODO tracking
    - Task lists (both ordered and unordered)
    - Progress tracking tables
    - Code examples and technical details
    - Automated progress reports
    - Formatted text with emphasis and links

    This demonstrates the full power of the org-mode parser for building
    sophisticated document management applications.
    """

    File.write!("example/comprehensive_workflow/README.md", example_content)

    # Actually run a simplified version to generate the files
    IO.puts("   Running simplified workflow to generate actual files...")

    doc =
      Org.Parser.parse("""
      #+TITLE: Example Project
      #+AUTHOR: Generator

      * Project Overview
      This is an example project created by the generator.

      * Development Phases
      ** DONE Planning
      Initial planning completed.

      ** TODO Implementation
      - Core features
      - User interface
      - Testing

      | Metric | Target | Current |
      |--------|--------|---------|
      | Coverage | 90% | 45% |
      | Performance | <100ms | TBD |

      #+BEGIN_SRC elixir
      defmodule Example do
        def hello, do: "Hello, World!"
      end
      #+END_SRC
      """)

    File.write!("example/comprehensive_workflow/complete_project.org", Org.to_org_string(doc))
    json_content = Org.to_json_map(doc) |> inspect(pretty: true, limit: :infinity)
    File.write!("example/comprehensive_workflow/complete_project.json", json_content)
  end

  def generate_real_world_example do
    IO.puts("6️⃣  Generating real-world use case examples...")

    example_content = """
    # Real-World Use Cases

    Here are practical examples of using the Elixir Org parser in real applications.

    ## Use Case 1: Documentation Management System

    ```elixir
    defmodule DocManager do
      @doc "Converts API documentation from org to structured data"
      def process_api_docs(org_file_path) do
        doc = Org.load_file(org_file_path)

        # Extract API endpoints (sections with specific pattern)
        endpoints = Org.NodeFinder.find_all(doc, fn
          %Org.Section{title: title} -> String.starts_with?(title, "GET ") or
                                       String.starts_with?(title, "POST ") or
                                       String.starts_with?(title, "PUT ") or
                                       String.starts_with?(title, "DELETE ")
          _ -> false
        end)

        # Convert to API spec format
        Enum.map(endpoints, fn endpoint ->
          %{
            method: endpoint.title |> String.split() |> hd(),
            path: endpoint.title |> String.split() |> Enum.at(1),
            description: extract_description(endpoint),
            parameters: extract_parameters_table(endpoint),
            examples: extract_code_blocks(endpoint)
          }
        end)
      end

      defp extract_description(%Org.Section{contents: contents}) do
        contents
        |> Enum.find(fn %Org.Paragraph{} -> true; _ -> false end)
        |> case do
          %Org.Paragraph{lines: lines} -> Enum.join(lines, " ")
          _ -> ""
        end
      end

      defp extract_parameters_table(%Org.Section{contents: contents}) do
        contents
        |> Enum.find(fn %Org.Table{} -> true; _ -> false end)
        |> case do
          %Org.Table{rows: rows} -> parse_parameter_table(rows)
          _ -> []
        end
      end

      defp extract_code_blocks(%Org.Section{contents: contents}) do
        Enum.filter(contents, fn %Org.CodeBlock{} -> true; _ -> false end)
      end
    end
    ```

    ## Use Case 2: Project Status Dashboard

    ```elixir
    defmodule StatusDashboard do
      @doc "Generates dashboard data from project org files"
      def generate_dashboard(project_files) do
        projects = Enum.map(project_files, fn file ->
          doc = Org.load_file(file)

          %{
            name: extract_title(doc),
            todos: count_todos(doc),
            done: count_done(doc),
            high_priority: count_high_priority(doc),
            last_update: extract_last_update(doc),
            progress_metrics: extract_metrics_table(doc)
          }
        end)

        %{
          total_projects: length(projects),
          total_tasks: Enum.sum(Enum.map(projects, &(&1.todos + &1.done))),
          completion_rate: calculate_completion_rate(projects),
          projects: projects
        }
      end

      defp extract_title(%Org.Document{comments: comments}) do
        comments
        |> Enum.find(&String.starts_with?(&1, "+TITLE:"))
        |> case do
          "+TITLE: " <> title -> title
          _ -> "Untitled Project"
        end
      end

      defp count_todos(doc) do
        Org.NodeFinder.find_all(doc, fn
          %Org.Section{todo_keyword: "TODO"} -> true
          _ -> false
        end)
        |> length()
      end

      defp count_done(doc) do
        Org.NodeFinder.find_all(doc, fn
          %Org.Section{todo_keyword: "DONE"} -> true
          _ -> false
        end)
        |> length()
      end
    end
    ```

    ## Use Case 3: Meeting Notes Processor

    ```elixir
    defmodule MeetingProcessor do
      @doc "Processes meeting notes and extracts action items"
      def process_meeting_notes(notes_file) do
        doc = Org.load_file(notes_file)

        %{
          meeting_info: extract_meeting_info(doc),
          attendees: extract_attendees(doc),
          agenda_items: extract_agenda_items(doc),
          action_items: extract_action_items(doc),
          decisions: extract_decisions(doc),
          next_meeting: extract_next_meeting(doc)
        }
      end

      defp extract_action_items(doc) do
        # Find sections marked as TODO or with "Action" in title
        Org.NodeFinder.find_all(doc, fn
          %Org.Section{todo_keyword: "TODO"} -> true
          %Org.Section{title: title} -> String.contains?(String.downcase(title), "action")
          _ -> false
        end)
        |> Enum.map(fn section ->
          %{
            title: section.title,
            assignee: extract_assignee(section),
            due_date: extract_due_date(section),
            priority: section.priority,
            description: extract_section_content(section)
          }
        end)
      end

      defp extract_decisions(doc) do
        # Find sections with "Decision" in title
        Org.NodeFinder.find_all(doc, fn
          %Org.Section{title: title} -> String.contains?(String.downcase(title), "decision")
          _ -> false
        end)
        |> Enum.map(&extract_section_content/1)
      end
    end
    ```

    ## Use Case 4: Content Management for Static Site

    ```elixir
    defmodule StaticSiteGenerator do
      @doc "Converts org files to website content"
      def generate_site(content_dir, output_dir) do
        content_dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".org"))
        |> Enum.each(fn file ->
          doc = Org.load_file(Path.join(content_dir, file))

          # Convert to different output formats
          generate_html_page(doc, output_dir, file)
          generate_json_data(doc, output_dir, file)
          generate_rss_entry(doc, output_dir, file)
        end)
      end

      defp generate_html_page(doc, output_dir, filename) do
        # Extract frontmatter
        title = extract_title(doc)
        date = extract_date(doc)
        tags = extract_tags(doc)

        # Convert content to HTML
        html_content = doc
        |> Org.to_org_string()
        |> convert_org_to_html()  # Your HTML conversion logic

        # Generate HTML file
        html = build_html_template(title, date, tags, html_content)

        output_file = Path.join(output_dir, String.replace(filename, ".org", ".html"))
        File.write!(output_file, html)
      end

      defp generate_json_data(doc, output_dir, filename) do
        # Create structured data for API consumption
        data = %{
          title: extract_title(doc),
          date: extract_date(doc),
          tags: extract_tags(doc),
          sections: extract_all_sections(doc),
          word_count: calculate_word_count(doc),
          reading_time: calculate_reading_time(doc)
        }

        output_file = Path.join(output_dir, String.replace(filename, ".org", ".json"))
        File.write!(output_file, Jason.encode!(data, pretty: true))
      end
    end
    ```

    ## Use Case 5: Knowledge Base Search

    ```elixir
    defmodule KnowledgeBase do
      @doc "Indexes org files for full-text search"
      def build_search_index(knowledge_base_dir) do
        knowledge_base_dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".org"))
        |> Enum.reduce(%{}, fn file, acc ->
          doc = Org.load_file(Path.join(knowledge_base_dir, file))

          # Extract searchable content
          sections = extract_searchable_sections(doc)

          # Build index entries
          Map.put(acc, file, %{
            title: extract_title(doc),
            tags: extract_tags(doc),
            sections: sections,
            full_text: Org.to_org_string(doc)
          })
        end)
      end

      @doc "Searches knowledge base"
      def search(index, query) do
        query = String.downcase(query)

        Enum.flat_map(index, fn {file, content} ->
          matches = find_matches_in_content(content, query)
          Enum.map(matches, &Map.put(&1, :file, file))
        end)
        |> Enum.sort_by(& &1.relevance, :desc)
      end

      defp find_matches_in_content(content, query) do
        # Search in title
        title_matches = if String.contains?(String.downcase(content.title), query) do
          [%{type: :title, content: content.title, relevance: 10}]
        else
          []
        end

        # Search in sections
        section_matches = Enum.flat_map(content.sections, fn section ->
          if String.contains?(String.downcase(section.title), query) do
            [%{type: :section, content: section.title, relevance: 5}]
          else
            []
          end
        end)

        # Search in full text
        text_matches = if String.contains?(String.downcase(content.full_text), query) do
          [%{type: :content, content: extract_context(content.full_text, query), relevance: 1}]
        else
          []
        end

        title_matches ++ section_matches ++ text_matches
      end
    end
    ```

    ## Use Case 6: Task Management Integration

    ```elixir
    defmodule TaskManager do
      @doc "Syncs org TODO items with external task management system"
      def sync_with_external_system(org_files, api_client) do
        # Extract all tasks from org files
        all_tasks = Enum.flat_map(org_files, fn file ->
          doc = Org.load_file(file)
          extract_tasks_with_metadata(doc, file)
        end)

        # Sync with external system
        Enum.each(all_tasks, fn task ->
          case task.external_id do
            nil -> create_external_task(task, api_client)
            id -> update_external_task(id, task, api_client)
          end
        end)

        # Update org files with external IDs
        update_org_files_with_external_ids(all_tasks, org_files)
      end

      defp extract_tasks_with_metadata(doc, filename) do
        Org.NodeFinder.find_all(doc, fn
          %Org.Section{todo_keyword: keyword} when keyword in ["TODO", "DOING", "DONE"] -> true
          _ -> false
        end)
        |> Enum.map(fn section ->
          %{
            title: section.title,
            status: section.todo_keyword,
            priority: section.priority,
            file: filename,
            path: Org.NodeFinder.path_to_node(doc, section),
            external_id: extract_external_id(section),
            due_date: extract_due_date(section),
            tags: extract_section_tags(section)
          }
        end)
      end

      defp create_external_task(task, api_client) do
        external_task = %{
          title: task.title,
          description: task.description,
          status: map_status_to_external(task.status),
          priority: map_priority_to_external(task.priority),
          due_date: task.due_date,
          tags: task.tags
        }

        case api_client.create_task(external_task) do
          {:ok, %{id: external_id}} ->
            # Store mapping for later update of org file
            {:ok, external_id}
          {:error, reason} ->
            {:error, reason}
        end
      end
    end
    ```

    These examples demonstrate how the org parser can be integrated into
    real-world applications for:

    - **Documentation Systems**: Convert org files to API specs
    - **Project Dashboards**: Aggregate status from multiple projects
    - **Meeting Management**: Extract action items and decisions
    - **Static Site Generation**: Convert content to web formats
    - **Knowledge Management**: Build searchable content indexes
    - **Task Management**: Sync with external systems

    The parser's ability to both read and write org-mode content makes it
    perfect for building sophisticated document management and workflow
    automation systems.
    """

    File.write!("example/real_world_examples/README.md", example_content)
  end
end

# Run the example generator
ExampleGenerator.main()
