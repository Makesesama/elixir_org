#!/usr/bin/env elixir

# Simple Org-mode to HTML converter example
# Usage: elixir converter.exs sample.org output.html

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
            body { font-family: 'Segoe UI', sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.6; }
            h1 { color: #2c3e50; border-bottom: 2px solid #3498db; }
            h2 { color: #34495e; border-bottom: 1px solid #bdc3c7; }
            h3 { color: #7f8c8d; }
            .todo { color: #e74c3c; font-weight: bold; }
            .done { color: #27ae60; font-weight: bold; }
            .priority-A { color: #e74c3c; }
            .priority-B { color: #f39c12; }
            .priority-C { color: #3498db; }
            table { border-collapse: collapse; width: 100%; margin: 20px 0; }
            th, td { border: 1px solid #bdc3c7; padding: 10px; text-align: left; }
            th { background-color: #ecf0f1; }
            pre { background-color: #f8f9fa; padding: 15px; border-left: 4px solid #3498db; overflow-x: auto; }
            code { background-color: #f8f9fa; padding: 2px 4px; border-radius: 3px; }
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
    sections
    |> Enum.map(&section_to_html(&1, level))
    |> Enum.join("\n")
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
    todo_html = case section.todo_keyword do
      "TODO" -> "<span class=\"todo\">TODO</span> "
      "DONE" -> "<span class=\"done\">DONE</span> "
      _ -> ""
    end

    priority_html = case section.priority do
      p when p in ["A", "B", "C"] -> "<span class=\"priority-#{p}\">[##{p}]</span> "
      _ -> ""
    end

    "#{todo_html}#{priority_html}#{section.title}"
  end

  defp contents_to_html(section_or_doc) do
    section_or_doc
    |> Org.contents()
    |> Enum.map(&content_to_html/1)
    |> Enum.join("\n")
  end

  defp content_to_html(%Org.Paragraph{lines: lines}) do
    content = lines |> Enum.join(" ") |> String.trim()
    if content != "", do: "<p>#{content}</p>", else: ""
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

  defp content_to_html(_), do: ""

  defp table_row_to_html(%Org.Table.Row{cells: cells}) do
    cell_html = Enum.map(cells, fn cell -> 
      "<td>#{String.trim(cell)}</td>" 
    end)
    "<tr>#{Enum.join(cell_html, "")}</tr>"
  end

  defp table_row_to_html(%Org.Table.Separator{}) do
    # Skip separators in HTML output
    ""
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