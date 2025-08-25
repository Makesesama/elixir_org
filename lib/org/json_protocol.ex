defprotocol Org.JSONEncodable do
  @moduledoc """
  Protocol for encoding Org structures to JSON-compatible maps.

  This protocol allows all Org structs to be easily converted to
  JSON-encodable data structures.
  """

  @doc "Converts the given struct to a JSON-encodable map"
  def to_json_map(data)
end

# Implementations for all Org structs

defimpl Org.JSONEncodable, for: Org.Document do
  def to_json_map(doc) do
    %{
      type: "document",
      comments: doc.comments,
      sections: Enum.map(doc.sections, &Org.JSONEncodable.to_json_map/1),
      contents: Enum.map(doc.contents, &Org.JSONEncodable.to_json_map/1)
    }
  end
end

defimpl Org.JSONEncodable, for: Org.Section do
  def to_json_map(section) do
    %{
      type: "section",
      title: section.title,
      todo_keyword: section.todo_keyword,
      priority: section.priority,
      children: Enum.map(section.children, &Org.JSONEncodable.to_json_map/1),
      contents: Enum.map(section.contents, &Org.JSONEncodable.to_json_map/1)
    }
  end
end

defimpl Org.JSONEncodable, for: Org.Paragraph do
  def to_json_map(para) do
    %{
      type: "paragraph",
      lines:
        Enum.map(para.lines, fn
          %Org.FormattedText{} = formatted -> Org.JSONEncodable.to_json_map(formatted)
          line when is_binary(line) -> line
        end)
    }
  end
end

defimpl Org.JSONEncodable, for: Org.FormattedText do
  def to_json_map(formatted) do
    %{
      type: "formatted_text",
      spans:
        Enum.map(formatted.spans, fn
          %Org.FormattedText.Span{} = span -> Org.JSONEncodable.to_json_map(span)
          %Org.FormattedText.Link{} = link -> Org.JSONEncodable.to_json_map(link)
          text when is_binary(text) -> text
        end)
    }
  end
end

defimpl Org.JSONEncodable, for: Org.FormattedText.Span do
  def to_json_map(span) do
    %{
      type: "span",
      format: span.format,
      content: span.content
    }
  end
end

defimpl Org.JSONEncodable, for: Org.FormattedText.Link do
  def to_json_map(link) do
    %{
      type: "link",
      url: link.url,
      description: link.description
    }
  end
end

defimpl Org.JSONEncodable, for: Org.List do
  def to_json_map(list) do
    %{
      type: "list",
      items: Enum.map(list.items, &Org.JSONEncodable.to_json_map/1)
    }
  end
end

defimpl Org.JSONEncodable, for: Org.List.Item do
  def to_json_map(item) do
    %{
      type: "list_item",
      content: item.content,
      indent: item.indent,
      ordered: item.ordered,
      number: item.number,
      children: Enum.map(item.children, &Org.JSONEncodable.to_json_map/1)
    }
  end
end

defimpl Org.JSONEncodable, for: Org.Table do
  def to_json_map(table) do
    %{
      type: "table",
      rows: Enum.map(table.rows, &Org.JSONEncodable.to_json_map/1)
    }
  end
end

defimpl Org.JSONEncodable, for: Org.Table.Row do
  def to_json_map(row) do
    %{
      type: "table_row",
      cells: row.cells
    }
  end
end

defimpl Org.JSONEncodable, for: Org.Table.Separator do
  def to_json_map(_separator) do
    %{
      type: "table_separator"
    }
  end
end

defimpl Org.JSONEncodable, for: Org.CodeBlock do
  def to_json_map(code_block) do
    %{
      type: "code_block",
      lang: code_block.lang,
      details: code_block.details,
      lines: code_block.lines
    }
  end
end
