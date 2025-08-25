#!/usr/bin/env elixir

# Example: Demonstrate write functionality for org-mode documents
# Usage: elixir -pa _build/dev/lib/org/ebin write_example.exs

defmodule WriteExample do
  def main do
    IO.puts("=== Org Document Write Mode Example ===\n")

    # Start with a simple document
    original_text = """
    * Project Management
    This is the main project.

    * Resources
    Links and references.
    """

    IO.puts("Original document:")
    IO.puts(original_text)
    IO.puts("\n" <> String.duplicate("=", 50) <> "\n")

    # Parse the document
    doc = Org.Parser.parse(original_text)

    # 1. Add a new section under "Project Management"
    IO.puts("1. Adding 'Tasks' section under 'Project Management'...")
    doc = Org.add_section(doc, ["Project Management"], "Tasks", "TODO", "A")

    # 2. Add content to the Tasks section
    IO.puts("2. Adding content to Tasks section...")
    task_para = %Org.Paragraph{lines: ["Here are the main tasks to complete."]}
    doc = Org.add_content(doc, ["Project Management", "Tasks"], task_para)

    # 3. Add sub-tasks
    IO.puts("3. Adding sub-tasks...")
    doc = Org.add_section(doc, ["Project Management", "Tasks"], "Setup Environment", "TODO", "A")
    doc = Org.add_section(doc, ["Project Management", "Tasks"], "Write Tests", "TODO", "B")
    doc = Org.add_section(doc, ["Project Management", "Tasks"], "Documentation", "TODO", "C")

    # 4. Add content to sub-tasks
    IO.puts("4. Adding content to sub-tasks...")
    setup_para = %Org.Paragraph{lines: ["Install dependencies and configure development environment."]}
    doc = Org.add_content(doc, ["Project Management", "Tasks", "Setup Environment"], setup_para)

    tests_para = %Org.Paragraph{lines: ["Write comprehensive unit and integration tests."]}
    doc = Org.add_content(doc, ["Project Management", "Tasks", "Write Tests"], tests_para)

    # 5. Add a code block example
    IO.puts("5. Adding code block example...")

    code_block = %Org.CodeBlock{
      lang: "elixir",
      details: "",
      lines: [
        "# Example test",
        "defmodule MyTest do",
        "  use ExUnit.Case",
        "  ",
        "  test \"basic functionality\" do",
        "    assert true",
        "  end",
        "end"
      ]
    }

    doc = Org.add_content(doc, ["Project Management", "Tasks", "Write Tests"], code_block)

    # 6. Update a section to mark it as DONE
    IO.puts("6. Marking 'Setup Environment' as DONE...")

    doc =
      Org.update_node(doc, ["Project Management", "Tasks", "Setup Environment"], fn section ->
        %{section | todo_keyword: "DONE"}
      end)

    # 7. Add a resource link under Resources
    IO.puts("7. Adding resources...")
    doc = Org.add_section(doc, ["Resources"], "Documentation Links")

    # Create a paragraph with formatted text (links)
    formatted_text = %Org.FormattedText{
      spans: [
        "See the official ",
        %Org.FormattedText.Link{url: "https://elixir-lang.org", description: "Elixir documentation"},
        " for more information about ",
        %Org.FormattedText.Span{format: :bold, content: "pattern matching"},
        " and ",
        %Org.FormattedText.Span{format: :italic, content: "concurrency"},
        "."
      ]
    }

    doc_para = %Org.Paragraph{lines: [formatted_text]}
    doc = Org.add_content(doc, ["Resources", "Documentation Links"], doc_para)

    # 8. Add a table with project statistics
    IO.puts("8. Adding project statistics table...")
    doc = Org.add_section(doc, ["Project Management"], "Statistics")

    stats_table = %Org.Table{
      rows: [
        %Org.Table.Row{cells: ["Metric", "Value", "Status"]},
        %Org.Table.Separator{},
        %Org.Table.Row{cells: ["Tasks Completed", "1", "Good"]},
        %Org.Table.Row{cells: ["Tasks Remaining", "2", "In Progress"]},
        %Org.Table.Row{cells: ["Code Coverage", "85%", "Good"]},
        %Org.Table.Row{cells: ["Documentation", "75%", "Needs Work"]}
      ]
    }

    doc = Org.add_content(doc, ["Project Management", "Statistics"], stats_table)

    # 9. Insert a section at a specific position
    IO.puts("9. Inserting 'Planning' section before 'Tasks'...")
    doc = Org.Writer.insert_section(doc, ["Project Management"], {:before, "Tasks"}, "Planning", "TODO", "A")
    planning_para = %Org.Paragraph{lines: ["Initial planning and requirements gathering."]}
    doc = Org.add_content(doc, ["Project Management", "Planning"], planning_para)

    # 10. Demonstrate finding nodes
    IO.puts("10. Finding and displaying node information...")
    tasks_section = Org.find_node(doc, ["Project Management", "Tasks"])
    IO.puts("   Found Tasks section with #{length(tasks_section.children)} sub-tasks")

    # Find all TODO items
    todo_items =
      Org.NodeFinder.find_all(doc, fn
        %Org.Section{todo_keyword: "TODO"} -> true
        _ -> false
      end)

    IO.puts("   Found #{length(todo_items)} TODO items")

    # Find all DONE items
    done_items =
      Org.NodeFinder.find_all(doc, fn
        %Org.Section{todo_keyword: "DONE"} -> true
        _ -> false
      end)

    IO.puts("   Found #{length(done_items)} DONE items")

    # Final result
    IO.puts("\n" <> String.duplicate("=", 50))
    IO.puts("Final document as org-mode text:")
    IO.puts(String.duplicate("=", 50))

    final_text = Org.to_org_string(doc)
    IO.puts(final_text)

    # Also save to file
    File.write!("example/generated_document.org", final_text)
    IO.puts("\n" <> String.duplicate("=", 50))
    IO.puts("Document saved to example/generated_document.org")

    # Show JSON representation
    IO.puts("\nJSON representation (first 500 chars):")
    json_map = Org.to_json_map(doc)
    json_preview = inspect(json_map, pretty: true, limit: :infinity) |> String.slice(0..500)
    IO.puts(json_preview <> "...")

    IO.puts("\n=== Write Example Complete! ===")
  end
end

# Run the example
WriteExample.main()
