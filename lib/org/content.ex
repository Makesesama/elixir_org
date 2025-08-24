defprotocol Org.Content do
  @moduledoc """
  Enhanced protocol for org-mode content elements.

  Provides a unified interface for all content types including:
  - Structural operations (reverse, merge, split)
  - Type identification and metadata
  - Content extraction and transformation
  - Validation and normalization
  """

  @doc """
  Returns the content type as an atom.

  Examples:
  - %Org.Paragraph{} -> :paragraph
  - %Org.Table{} -> :table
  - %Org.CodeBlock{} -> :code_block
  """
  def content_type(content)

  @doc """
  Reverses the content's internal structure.
  Used by parser to correct order after building in reverse.
  """
  def reverse_recursive(content)

  @doc """
  Checks if this content can be merged with another content of the same type.
  Used for combining adjacent paragraphs, table rows, etc.
  """
  def can_merge?(content, other_content)

  @doc """
  Merges this content with another content of the same type.
  Returns the merged content or raises if merge is not possible.
  """
  def merge(content, other_content)

  @doc """
  Validates the content structure and returns {:ok, content} or {:error, reason}.
  """
  def validate(content)

  @doc """
  Returns a plain text representation of the content.
  Useful for search, indexing, and basic export.
  """
  def to_text(content)

  @doc """
  Returns metadata about the content (line count, size, etc.).
  """
  def metadata(content)

  @doc """
  Checks if the content is empty or contains no meaningful data.
  """
  def empty?(content)
end

defmodule Org.ContentBuilder do
  @moduledoc """
  Manages content creation, merging, and attachment logic.

  This centralizes all the complex logic that was scattered across
  Document, Parser, and individual content modules.
  """

  alias Org.Content

  @doc """
  Creates or extends content based on the current parser state.

  This replaces the scattered logic in the parser that checked modes
  and decided whether to create new content or extend existing.
  """
  def handle_content(current_content_list, new_token, parser_context) do
    case new_token do
      {:text, line} ->
        handle_text_line(current_content_list, line, parser_context)

      {:table_row, cells} ->
        handle_table_row(current_content_list, cells, parser_context)

      {:list_item, indent, ordered, number, content} ->
        handle_list_item(current_content_list, indent, ordered, number, content, parser_context)

      {:begin_src, lang, details} ->
        handle_code_block_start(current_content_list, lang, details, parser_context)

      {:raw_line, line} ->
        handle_code_block_line(current_content_list, line, parser_context)

      {:end_src} ->
        handle_code_block_end(current_content_list, parser_context)

      {:empty_line} ->
        handle_empty_line(current_content_list, parser_context)

      _ ->
        {:unhandled, current_content_list}
    end
  end

  @doc """
  Attempts to merge adjacent compatible content elements.

  For example:
  - Adjacent paragraphs separated only by empty lines
  - Table rows that should be part of the same table
  - List items that form a cohesive list
  """
  def merge_compatible_content(content_list) do
    # Merge adjacent content and fix the order
    merge_adjacent_content(content_list, [])
    |> Enum.reverse()
  end

  @doc """
  Validates all content in a list and returns errors for invalid content.
  """
  def validate_content_list(content_list) do
    Enum.reduce(content_list, {:ok, []}, fn content, {:ok, validated} ->
      case Content.validate(content) do
        {:ok, valid_content} -> {:ok, [valid_content | validated]}
        {:error, reason} -> {:error, {content, reason}}
      end
    end)
  end

  # Private implementation functions

  defp handle_text_line([%Org.Paragraph{} = para | rest], line, context) do
    case context.mode do
      :paragraph ->
        # Continue existing paragraph
        extended_para = Org.Paragraph.prepend_line(para, line)
        {:handled, [extended_para | rest], :paragraph}

      _ ->
        # After empty line or different content - create new paragraph
        new_para = Org.Paragraph.new([line])
        {:handled, [new_para | [para | rest]], :paragraph}
    end
  end

  defp handle_text_line(content_list, line, _context) do
    # Create new paragraph
    new_para = Org.Paragraph.new([line])
    {:handled, [new_para | content_list], :paragraph}
  end

  defp handle_table_row([%Org.Table{} = table | rest], cells, _context) do
    # Extend existing table
    extended_table = Org.Table.prepend_row(table, cells)
    {:handled, [extended_table | rest], :table}
  end

  defp handle_table_row(content_list, cells, _context) do
    # Create new table
    new_table = Org.Table.new([cells])
    {:handled, [new_table | content_list], :table}
  end

  defp handle_list_item([%Org.List{} = list | rest], indent, ordered, number, content, _context) do
    # Extend existing list
    item = %Org.List.Item{content: content, indent: indent, ordered: ordered, number: number}
    extended_list = Org.List.prepend_item(list, item)
    {:handled, [extended_list | rest], :list}
  end

  defp handle_list_item(content_list, indent, ordered, number, content, _context) do
    # Create new list
    item = %Org.List.Item{content: content, indent: indent, ordered: ordered, number: number}
    new_list = Org.List.new([item])
    {:handled, [new_list | content_list], :list}
  end

  defp handle_code_block_start(content_list, lang, details, _context) do
    # Always create new code block
    new_code_block = Org.CodeBlock.new(lang, details)
    {:handled, [new_code_block | content_list], :code_block}
  end

  defp handle_code_block_line([%Org.CodeBlock{} = code_block | rest], line, _context) do
    # Extend existing code block
    extended_code_block = Org.CodeBlock.prepend_line(code_block, line)
    {:handled, [extended_code_block | rest], :code_block}
  end

  defp handle_code_block_line(content_list, _line, _context) do
    # This shouldn't happen - raw lines should only come after BEGIN_SRC
    {:error, {:unexpected_raw_line, content_list}}
  end

  defp handle_code_block_end(content_list, _context) do
    # Code block is complete, no changes needed
    {:handled, content_list, :normal}
  end

  defp handle_empty_line(content_list, context) do
    # Empty lines can end certain content types or be ignored
    case context.mode do
      # End paragraph mode
      :paragraph -> {:handled, content_list, :normal}
      # End list mode
      :list -> {:handled, content_list, :normal}
      # End table mode
      :table -> {:handled, content_list, :normal}
      # No change
      _ -> {:handled, content_list, context.mode}
    end
  end

  defp merge_adjacent_content([], acc), do: acc

  defp merge_adjacent_content([content], acc) do
    [content | acc]
  end

  defp merge_adjacent_content([first, second | rest], acc) do
    if Content.can_merge?(first, second) do
      # Merge in reverse order since the list is in parser order (reversed)
      merged = Content.merge(second, first)
      merge_adjacent_content([merged | rest], acc)
    else
      merge_adjacent_content([second | rest], [first | acc])
    end
  end
end

# Default implementation for all types
defimpl Org.Content, for: [Atom, BitString, Float, Function, Integer, List, Map, PID, Port, Reference, Tuple] do
  def content_type(_content), do: :unknown
  def reverse_recursive(content), do: content
  def can_merge?(_content, _other), do: false
  def merge(_content, _other), do: raise("Cannot merge unknown content types")
  def validate(content), do: {:error, "Unknown content type: #{inspect(content)}"}
  def to_text(_content), do: ""
  def metadata(_content), do: %{}
  def empty?(_content), do: true
end
