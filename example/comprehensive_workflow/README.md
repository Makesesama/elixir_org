# Comprehensive Workflow Example

This example demonstrates a complete workflow combining parsing, modification, 
and serialization for a project management scenario.

```elixir
defmodule ProjectManager do
  @doc "Creates a new project structure"
  def create_project(name, description) do
    # Start with basic structure
    doc_text = """
    #+TITLE: #{name}
    #+AUTHOR: Project Manager
    #+DATE: #{Date.utc_today()}
    
    * Project Overview
    #{description}
    
    * Status
    Project initialized and ready for development.
    """
    
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
        "mix new #{String.downcase(String.replace("My Project", " ", "_"))}",
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
        "  database_url: System.get_env(\"DATABASE_URL\")"
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
        %Org.Table.Row{cells: ["Completed", to_string(length(done_items)), "#{round(length(done_items) / (length(done_items) + length(todo_items)) * 100)}%"]},
        %Org.Table.Row{cells: ["Remaining", to_string(length(todo_items)), "#{round(length(todo_items) / (length(done_items) + length(todo_items)) * 100)}%"]},
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
    IO.puts("🚀 Running Complete Project Management Workflow\n")
    
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
    IO.puts("\n✅ Workflow completed successfully!")
    IO.puts("📊 Project Statistics:")
    
    # Count different elements
    sections = Org.NodeFinder.find_all(doc, fn %Org.Section{} -> true; _ -> false end)
    tables = Org.NodeFinder.find_all(doc, fn %Org.Table{} -> true; _ -> false end)
    code_blocks = Org.NodeFinder.find_all(doc, fn %Org.CodeBlock{} -> true; _ -> false end)
    lists = Org.NodeFinder.find_all(doc, fn %Org.List{} -> true; _ -> false end)
    paragraphs = Org.NodeFinder.find_all(doc, fn %Org.Paragraph{} -> true; _ -> false end)
    
    IO.puts("- Sections: #{length(sections)}")
    IO.puts("- Tables: #{length(tables)}")  
    IO.puts("- Code Blocks: #{length(code_blocks)}")
    IO.puts("- Lists: #{length(lists)}")
    IO.puts("- Paragraphs: #{length(paragraphs)}")
    
    IO.puts("\n📁 Files generated:")
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
