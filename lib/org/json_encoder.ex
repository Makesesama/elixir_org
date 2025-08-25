defmodule Org.JSONEncoder do
  @moduledoc """
  JSON encoding for Org-mode structures.

  Provides JSON encoding functionality for all Org structs,
  making them suitable for API responses and data exchange.
  """

  @doc """
  Encodes an Org document or any Org struct to a JSON-encodable map.
  """
  def encode(%Org.Document{} = doc) do
    %{
      type: "document",
      comments: doc.comments,
      sections: Enum.map(doc.sections, &encode/1),
      contents: Enum.map(doc.contents, &encode/1)
    }
  end

  def encode(%Org.Section{} = section) do
    %{
      type: "section",
      title: section.title,
      todo_keyword: section.todo_keyword,
      priority: section.priority,
      children: Enum.map(section.children, &encode/1),
      contents: Enum.map(section.contents, &encode/1)
    }
  end

  def encode(%Org.Paragraph{} = para) do
    %{
      type: "paragraph",
      lines: Enum.map(para.lines, &encode_line/1)
    }
  end

  def encode(%Org.FormattedText{} = formatted) do
    %{
      type: "formatted_text",
      spans: Enum.map(formatted.spans, &encode_span/1)
    }
  end

  def encode(%Org.FormattedText.Span{} = span) do
    %{
      type: "span",
      format: span.format,
      content: span.content
    }
  end

  def encode(%Org.FormattedText.Link{} = link) do
    %{
      type: "link",
      url: link.url,
      description: link.description
    }
  end

  def encode(%Org.List{} = list) do
    %{
      type: "list",
      items: Enum.map(list.items, &encode/1)
    }
  end

  def encode(%Org.List.Item{} = item) do
    %{
      type: "list_item",
      content: item.content,
      indent: item.indent,
      ordered: item.ordered,
      number: item.number,
      children: Enum.map(item.children, &encode/1)
    }
  end

  def encode(%Org.Table{} = table) do
    %{
      type: "table",
      rows: Enum.map(table.rows, &encode/1)
    }
  end

  def encode(%Org.Table.Row{} = row) do
    %{
      type: "table_row",
      cells: row.cells
    }
  end

  def encode(%Org.Table.Separator{}) do
    %{
      type: "table_separator"
    }
  end

  def encode(%Org.CodeBlock{} = code_block) do
    %{
      type: "code_block",
      lang: code_block.lang,
      details: code_block.details,
      lines: code_block.lines
    }
  end

  # Handle any other types that might appear (fallback)
  def encode(value) when is_binary(value), do: value
  def encode(value) when is_nil(value), do: nil
  def encode(value) when is_number(value), do: value
  def encode(value) when is_boolean(value), do: value
  def encode(value) when is_atom(value), do: to_string(value)

  # Private helper to encode a line (which can be string or FormattedText)
  defp encode_line(%Org.FormattedText{} = formatted), do: encode(formatted)
  defp encode_line(line) when is_binary(line), do: line

  # Private helper to encode a span
  defp encode_span(%Org.FormattedText.Span{} = span), do: encode(span)
  defp encode_span(%Org.FormattedText.Link{} = link), do: encode(link)
  defp encode_span(text) when is_binary(text), do: text

  @doc """
  Converts an Org structure to a JSON string using Elixir's built-in JSON library.

  Note: Requires OTP 27+ for the :json module, or you can use Jason/Poison.
  For compatibility, this returns the JSON-encodable map structure.
  """
  def to_json(org_struct) do
    org_struct
    |> encode()
    |> json_library_encode()
  end

  # Use the appropriate JSON library based on what's available
  defp json_library_encode(data) do
    # OTP 27+ has built-in :json module
    if Code.ensure_loaded?(:json) do
      :json.encode(data)
    else
      # Fallback to returning the map structure for manual encoding
      {:ok, data}
    end
  end
end
