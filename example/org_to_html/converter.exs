#!/usr/bin/env elixir

# Simple Org-mode to HTML converter example
# Usage: elixir converter.exs sample.org output.html

# Add the project root to the code path
project_root = Path.join(__DIR__, "../..")
Code.prepend_path(Path.join(project_root, "_build/dev/lib/org/ebin"))

# Load the main Mix project
Mix.install([
  {:org, path: project_root}
])

defmodule OrgToHtml do
  @moduledoc """
  A simple converter that transforms org-mode documents to HTML.
  """

  def convert_file(input_path, output_path) do
    # Load and parse the org document
    doc = Org.load_file(input_path)

    # Convert to HTML
    html = document_to_html(doc)

    # Write to output file
    File.write!(output_path, html)

    IO.puts("✓ Converted #{input_path} to #{output_path}")
  end

  defp document_to_html(doc) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Org Document</title>
        <style>
            body { 
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
                max-width: 800px; 
                margin: 0 auto; 
                padding: 20px; 
                line-height: 1.6; 
                color: #333;
            }
            h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
            h2 { color: #34495e; border-bottom: 1px solid #bdc3c7; padding-bottom: 5px; }
            h3 { color: #7f8c8d; }
            .todo { color: #e74c3c; font-weight: bold; }
            .done { color: #27ae60; font-weight: bold; }
            .priority-A { color: #e74c3c; font-weight: bold; }
            .priority-B { color: #f39c12; font-weight: bold; }
            .priority-C { color: #3498db; font-weight: bold; }
            table { border-collapse: collapse; width: 100%; margin: 20px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            th, td { border: 1px solid #bdc3c7; padding: 10px; text-align: left; }
            th { background-color: #ecf0f1; font-weight: bold; }
            pre { 
                background-color: #f8f9fa; 
                padding: 15px; 
                border-left: 4px solid #3498db; 
                overflow-x: auto; 
                border-radius: 4px;
                font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
            }
            code { 
                background-color: #f1f3f4; 
                padding: 2px 6px; 
                border-radius: 3px; 
                font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
                font-size: 0.9em;
                border: 1px solid #e1e5e9;
            }
            code.verbatim { 
                background-color: #e8f5e8; 
                color: #2c3e50; 
                border: 1px solid #a4d4a4;
            }
            strong { 
                font-weight: bold; 
                color: #2c3e50;
            }
            em { 
                font-style: italic; 
                color: #34495e;
            }
            u { 
                text-decoration: underline; 
                text-decoration-color: #3498db;
                text-underline-offset: 2px;
            }
            del { 
                text-decoration: line-through; 
                color: #7f8c8d; 
                opacity: 0.7;
            }
            a {
                color: #3498db;
                text-decoration: none;
                border-bottom: 1px solid transparent;
                transition: border-bottom-color 0.2s ease;
            }
            a:hover {
                color: #2980b9;
                border-bottom-color: #2980b9;
            }
            a:visited {
                color: #8e44ad;
            }
            ul, ol { margin: 20px 0; }
            li { margin: 5px 0; }
            ul ul, ol ol, ul ol, ol ul { margin: 10px 0; }
            p { margin: 15px 0; }
        </style>
    </head>
    <body>
    #{sections_to_html(doc.sections, 1)}
    #{contents_to_html(doc)}
    </body>
    </html>
    """
  end

  defp sections_to_html(sections, level) do
    Enum.map_join(sections, "\n", &section_to_html(&1, level))
  end

  defp section_to_html(section, level) do
    tag = "h#{level}"
    title_html = section_title_to_html(section)
    contents_html = contents_to_html(section)
    children_html = sections_to_html(section.children, level + 1)

    """
    <#{tag}>#{title_html}</#{tag}>
    #{contents_html}
    #{children_html}
    """
  end

  defp section_title_to_html(section) do
    todo_html =
      case section.todo_keyword do
        "TODO" -> "<span class=\"todo\">TODO</span> "
        "DONE" -> "<span class=\"done\">DONE</span> "
        _ -> ""
      end

    priority_html =
      case section.priority do
        p when p in ["A", "B", "C"] -> "<span class=\"priority-#{p}\">[##{p}]</span> "
        _ -> ""
      end

    "#{todo_html}#{priority_html}#{section.title}"
  end

  defp contents_to_html(section_or_doc) do
    section_or_doc
    |> Org.contents()
    |> Enum.map_join("\n", &content_to_html/1)
  end

  defp content_to_html(%Org.Paragraph{lines: lines}) do
    html_content =
      lines
      |> Enum.map_join(" ", &line_to_html/1)
      |> String.trim()

    if html_content != "", do: "<p>#{html_content}</p>", else: ""
  end

  defp content_to_html(%Org.Table{rows: rows}) do
    html_rows = Enum.map(rows, &table_row_to_html/1)

    """
    <table>
    #{Enum.join(html_rows, "\n")}
    </table>
    """
  end

  defp content_to_html(%Org.CodeBlock{lang: lang, lines: lines}) do
    code_content = Enum.join(lines, "\n")

    """
    <pre><code class="language-#{lang}">#{escape_html(code_content)}</code></pre>
    """
  end

  defp content_to_html(%Org.List{items: items}) do
    # Build nested structure and convert to HTML
    nested_items = Org.List.build_nested(items)
    list_html = Enum.map_join(nested_items, "\n", &list_item_to_html/1)

    # Determine if this is an ordered or unordered list based on first item
    tag =
      case List.first(nested_items) do
        %{ordered: true} -> "ol"
        _ -> "ul"
      end

    """
    <#{tag}>
    #{list_html}
    </#{tag}>
    """
  end

  defp content_to_html(_), do: ""

  defp table_row_to_html(%Org.Table.Row{cells: cells}) do
    cell_html =
      Enum.map(cells, fn cell ->
        "<td>#{String.trim(cell)}</td>"
      end)

    "<tr>#{Enum.join(cell_html, "")}</tr>"
  end

  defp table_row_to_html(%Org.Table.Separator{}) do
    # Skip separators in HTML output
    ""
  end

  defp list_item_to_html(%Org.List.Item{content: content, children: children}) do
    children_html =
      case children do
        [] ->
          ""

        _ ->
          # Determine tag based on first child
          child_tag =
            case List.first(children) do
              %{ordered: true} -> "ol"
              _ -> "ul"
            end

          child_items = Enum.map_join(children, "\n", &list_item_to_html/1)

          """
          <#{child_tag}>
          #{child_items}
          </#{child_tag}>
          """
      end

    # Parse content for formatting
    formatted_content = Org.FormattedText.parse(content)
    content_html = line_to_html(formatted_content)

    """
    <li>#{content_html}#{children_html}</li>
    """
  end

  # Convert a line (string or FormattedText) to HTML
  defp line_to_html(%Org.FormattedText{spans: spans}) do
    Enum.map_join(spans, "", &span_to_html/1)
  end

  defp line_to_html(line) when is_binary(line) do
    escape_html(line)
  end

  # Convert a formatted text span to HTML
  defp span_to_html(%Org.FormattedText.Span{format: format, content: content}) do
    escaped_content = escape_html(content)

    case format do
      :bold -> "<strong>#{escaped_content}</strong>"
      :italic -> "<em>#{escaped_content}</em>"
      :underline -> "<u>#{escaped_content}</u>"
      :code -> "<code>#{escaped_content}</code>"
      :verbatim -> "<code class=\"verbatim\">#{escaped_content}</code>"
      :strikethrough -> "<del>#{escaped_content}</del>"
    end
  end

  defp span_to_html(%Org.FormattedText.Link{url: url, description: nil}) do
    escaped_url = escape_html(url)
    "<a href=\"#{escaped_url}\">#{escaped_url}</a>"
  end

  defp span_to_html(%Org.FormattedText.Link{url: url, description: description}) do
    escaped_url = escape_html(url)
    escaped_description = escape_html(description)
    "<a href=\"#{escaped_url}\">#{escaped_description}</a>"
  end

  defp span_to_html(text) when is_binary(text) do
    escape_html(text)
  end

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end
end

# Main execution
case System.argv() do
  [input_file, output_file] ->
    if File.exists?(input_file) do
      OrgToHtml.convert_file(input_file, output_file)
    else
      IO.puts("Error: Input file '#{input_file}' not found")
      System.halt(1)
    end

  [input_file] ->
    output_file = Path.rootname(input_file) <> ".html"

    if File.exists?(input_file) do
      OrgToHtml.convert_file(input_file, output_file)
    else
      IO.puts("Error: Input file '#{input_file}' not found")
      System.halt(1)
    end

  _ ->
    IO.puts("""
    Usage: elixir converter.exs <input.org> [output.html]

    Examples:
      elixir converter.exs sample.org
      elixir converter.exs sample.org output.html
    """)

    System.halt(1)
end
