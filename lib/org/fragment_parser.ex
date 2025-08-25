defmodule Org.FragmentParser do
  @moduledoc """
  Provides functionality to parse fragments of org-mode text.

  This module enables parsing partial org-mode content while preserving
  styling information and position tracking. It's designed to support
  incremental editing without losing formatting.

  ## Fragment Types

  - `:section` - A complete section with header and content
  - `:content` - Content blocks (paragraphs, tables, code blocks, etc.)
  - `:line` - Single line fragments with formatting
  - `:text` - Text fragments with inline formatting

  ## Features

  - Position tracking for precise editing
  - Preserves original styling and whitespace
  - Supports incremental updates
  - Context-aware parsing
  """

  alias Org.{CodeBlock, List, Paragraph, Section, Table}

  @type fragment_type :: :section | :content | :line | :text
  @type position :: {line :: non_neg_integer(), column :: non_neg_integer()}
  @type range :: {start_pos :: position(), end_pos :: position()}

  @type fragment :: %{
          type: fragment_type(),
          content: any(),
          range: range(),
          original_text: String.t(),
          context: fragment_context()
        }

  @type fragment_context :: %{
          parent_type: atom() | nil,
          indent_level: non_neg_integer(),
          list_context: list_context() | nil,
          section_level: non_neg_integer() | nil
        }

  @type list_context :: %{
          type: :ordered | :unordered,
          base_indent: non_neg_integer(),
          item_number: non_neg_integer() | nil
        }

  @doc """
  Parses a fragment of org-mode text with position tracking.

  ## Options

  - `:type` - Expected fragment type (auto-detected if not provided)
  - `:start_position` - Starting position in the original document
  - `:context` - Parent context for proper parsing
  - `:preserve_whitespace` - Keep original whitespace (default: true)

  ## Examples

      iex> text = "** TODO [#A] Important task"
      iex> fragment = Org.FragmentParser.parse_fragment(text, type: :section)
      iex> fragment.content.title
      "Important task"
      
      iex> text = "This is *bold* and /italic/ text."
      iex> fragment = Org.FragmentParser.parse_fragment(text, type: :text)
      iex> length(fragment.content.spans)
      5
  """
  @spec parse_fragment(String.t(), keyword()) :: fragment()
  def parse_fragment(text, opts \\ []) do
    type = opts[:type] || detect_fragment_type(text)
    start_pos = opts[:start_position] || {1, 1}
    context = opts[:context] || %{}
    preserve_whitespace = Keyword.get(opts, :preserve_whitespace, true)

    {content, end_pos} = parse_by_type(text, type, start_pos, context)

    %{
      type: type,
      content: content,
      range: {start_pos, end_pos},
      original_text: if(preserve_whitespace, do: text, else: String.trim(text)),
      context: build_context(text, context)
    }
  end

  @doc """
  Parses multiple fragments from text, typically separated by newlines.

  ## Examples

      iex> text = "* Section 1\\n\\nSome content\\n\\n* Section 2"
      iex> fragments = Org.FragmentParser.parse_fragments(text)
      iex> length(fragments)
      3
  """
  @spec parse_fragments(String.t(), keyword()) :: [fragment()]
  def parse_fragments(text, opts \\ []) do
    lines = String.split(text, "\n", trim: false)
    context = opts[:context] || %{}

    {fragments, _} =
      lines
      |> Enum.with_index(1)
      |> Enum.reduce({[], context}, fn {line, line_num}, {acc_fragments, ctx} ->
        if String.trim(line) == "" do
          {acc_fragments, ctx}
        else
          fragment =
            parse_fragment(line,
              start_position: {line_num, 1},
              context: ctx,
              preserve_whitespace: true
            )

          updated_ctx = update_context_from_fragment(ctx, fragment)
          {[fragment | acc_fragments], updated_ctx}
        end
      end)

    Enum.reverse(fragments)
  end

  @doc """
  Updates an existing fragment with new content while preserving position info.

  ## Examples

      iex> fragment = Org.FragmentParser.parse_fragment("* Old title")
      iex> updated = Org.FragmentParser.update_fragment(fragment, "* New title")
      iex> updated.content.title
      "New title"
  """
  @spec update_fragment(fragment(), String.t()) :: fragment()
  def update_fragment(fragment, new_text) do
    opts = [
      type: fragment.type,
      start_position: elem(fragment.range, 0),
      context: fragment.context,
      preserve_whitespace: true
    ]

    parse_fragment(new_text, opts)
  end

  @doc """
  Renders a fragment back to org-mode text format.

  ## Examples

      iex> fragment = Org.FragmentParser.parse_fragment("** TODO Task")
      iex> Org.FragmentParser.render_fragment(fragment)
      "** TODO Task"
  """
  @spec render_fragment(fragment()) :: String.t()
  def render_fragment(%{type: type, content: content, context: context}) do
    render_by_type(content, type, context)
  end

  # Private functions

  defp detect_fragment_type(text) do
    trimmed = String.trim(text)

    cond do
      String.match?(trimmed, ~r/^\*+\s/) -> :section
      # List
      String.match?(trimmed, ~r/^(\s*[-+]|\s*\d+\.)/) -> :content
      # Table
      String.match?(trimmed, ~r/^\s*\|/) -> :content
      # Code block
      String.match?(trimmed, ~r/^#\+BEGIN_/) -> :content
      # Multi-line content
      String.contains?(text, "\n") -> :content
      # Formatted text
      String.contains?(trimmed, "*") or String.contains?(trimmed, "/") -> :text
      true -> :line
    end
  end

  defp parse_by_type(text, :section, start_pos, context) do
    # Parse section header using regex similar to lexer
    trimmed = String.trim(text)

    case Regex.run(~r/^(\*+)\s*(?:(TODO|DONE|CANCELLED)\s+)?(?:\[#([ABC])\]\s+)?(.*)/, trimmed) do
      [_, _stars, todo_keyword, priority, title] ->
        section = %Section{
          title: normalize_string(title),
          todo_keyword: normalize_keyword(todo_keyword),
          priority: normalize_keyword(priority),
          children: [],
          contents: []
        }

        end_pos = calculate_end_position(start_pos, text)
        {section, end_pos}

      nil ->
        # Fallback to line parsing
        parse_by_type(text, :line, start_pos, context)
    end
  end

  defp parse_by_type(text, :content, start_pos, _context) do
    # Try to parse as different content types
    content =
      cond do
        String.match?(String.trim(text), ~r/^(\s*[-+]|\s*\d+\.)/) ->
          parse_list_fragment(text)

        String.match?(String.trim(text), ~r/^\s*\|/) ->
          parse_table_fragment(text)

        String.match?(String.trim(text), ~r/^#\+BEGIN_/) ->
          parse_code_block_fragment(text)

        true ->
          %Paragraph{lines: [text]}
      end

    end_pos = calculate_end_position(start_pos, text)
    {content, end_pos}
  end

  defp parse_by_type(text, :text, start_pos, _context) do
    # Parse formatted text
    formatted_text = Org.FormattedText.parse(text)
    end_pos = calculate_end_position(start_pos, text)
    {formatted_text, end_pos}
  end

  defp parse_by_type(text, :line, start_pos, _context) do
    # Simple line parsing - preserve as is
    end_pos = calculate_end_position(start_pos, text)
    {text, end_pos}
  end

  defp parse_list_fragment(text) do
    lines = String.split(text, "\n", trim: false)
    items = parse_list_items(lines, 0)
    %List{items: items}
  end

  defp parse_list_items([], _base_indent), do: []

  defp parse_list_items([line | rest], base_indent) do
    case parse_list_item_line(line, base_indent) do
      {:ok, item} ->
        {remaining_lines, children} = extract_item_children(rest, item.indent + 1)
        item_with_children = %{item | children: parse_list_items(children, item.indent + 1)}
        [item_with_children | parse_list_items(remaining_lines, base_indent)]

      {:skip, _} ->
        parse_list_items(rest, base_indent)
    end
  end

  defp parse_list_item_line(line, base_indent) do
    if String.trim(line) == "" do
      {:skip, nil}
    else
      parse_list_item_match(line, base_indent)
    end
  end

  defp parse_list_item_match(line, base_indent) do
    case Regex.run(~r/^(\s*)([-+]|\d+\.)\s+(.*)/, line) do
      [_, indent_str, bullet, content] ->
        create_list_item(indent_str, bullet, content, base_indent)

      nil ->
        {:skip, nil}
    end
  end

  defp create_list_item(indent_str, bullet, content, base_indent) do
    indent = String.length(indent_str) - base_indent
    ordered = String.match?(bullet, ~r/\d+\./)
    number = if ordered, do: parse_item_number(bullet), else: nil

    item = %List.Item{
      indent: max(indent, 0),
      ordered: ordered,
      number: number,
      content: String.trim(content),
      children: []
    }

    {:ok, item}
  end

  defp parse_item_number(bullet) do
    case Integer.parse(String.trim_trailing(bullet, ".")) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp extract_item_children(lines, target_indent) do
    {children, remaining} =
      Enum.split_while(lines, fn line ->
        if String.trim(line) == "" do
          true
        else
          indent = String.length(line) - String.length(String.trim_leading(line))
          indent >= target_indent
        end
      end)

    {remaining, children}
  end

  defp parse_table_fragment(text) do
    lines = String.split(text, "\n", trim: false)
    rows = Enum.map(lines, &parse_table_row/1)
    %Table{rows: Enum.reject(rows, &is_nil/1)}
  end

  defp parse_table_row(line) do
    trimmed = String.trim(line)

    cond do
      String.match?(trimmed, ~r/^\|[-\s\|]+\|$/) ->
        %Table.Separator{}

      String.starts_with?(trimmed, "|") and String.ends_with?(trimmed, "|") ->
        cells =
          trimmed
          |> String.slice(1..-2//1)
          |> String.split("|")
          |> Enum.map(&String.trim/1)

        %Table.Row{cells: cells}

      true ->
        nil
    end
  end

  defp parse_code_block_fragment(text) do
    lines = String.split(text, "\n")

    case lines do
      [begin_line | rest] ->
        case Regex.run(~r/^#\+BEGIN_SRC\s+(\S+)?\s*(.*)/, begin_line) do
          [_, lang, details] ->
            {code_lines, _} = extract_until_end_src(rest)

            %CodeBlock{
              lang: normalize_string(lang),
              details: normalize_string(details),
              lines: code_lines
            }

          nil ->
            %Paragraph{lines: [text]}
        end

      [] ->
        %Paragraph{lines: []}
    end
  end

  defp extract_until_end_src(lines) do
    case Enum.find_index(lines, &String.match?(&1, ~r/^#\+END_SRC/)) do
      nil -> {lines, []}
      index -> Enum.split(lines, index)
    end
  end

  defp build_context(text, base_context) do
    indent_level = String.length(text) - String.length(String.trim_leading(text))

    section_level =
      case Regex.run(~r/^(\*+)/, String.trim(text)) do
        [_, stars] -> String.length(stars)
        nil -> nil
      end

    list_context = detect_list_context(text)

    %{
      parent_type: Map.get(base_context, :parent_type),
      indent_level: indent_level,
      list_context: list_context,
      section_level: section_level
    }
  end

  defp detect_list_context(text) do
    case Regex.run(~r/^(\s*)([-+]|\d+\.)\s+/, text) do
      [_, indent_str, bullet] ->
        %{
          type: if(String.match?(bullet, ~r/\d+\./), do: :ordered, else: :unordered),
          base_indent: String.length(indent_str),
          item_number: parse_item_number(bullet)
        }

      nil ->
        nil
    end
  end

  defp calculate_end_position({start_line, start_col}, text) do
    lines = String.split(text, "\n")
    line_count = length(lines)

    if line_count == 1 do
      {start_line, start_col + String.length(text)}
    else
      last_line = Enum.at(lines, -1) || ""
      {start_line + line_count - 1, String.length(last_line) + 1}
    end
  end

  defp update_context_from_fragment(context, fragment) do
    case fragment.type do
      :section ->
        Map.put(context, :section_level, fragment.context.section_level)

      _ ->
        context
    end
  end

  defp render_by_type(%Section{} = section, :section, context) do
    level = context.section_level || 1
    stars = String.duplicate("*", level)
    todo_part = if section.todo_keyword, do: " #{section.todo_keyword}", else: ""
    priority_part = if section.priority, do: " [##{section.priority}]", else: ""

    "#{stars}#{todo_part}#{priority_part} #{section.title}"
  end

  defp render_by_type(%Paragraph{lines: lines}, :content, _context) do
    Enum.join(lines, "\n")
  end

  defp render_by_type(%List{} = list, :content, context) do
    base_indent = context.indent_level || 0
    render_list_items(list.items, base_indent) |> Enum.join("\n")
  end

  defp render_by_type(%Table{} = table, :content, _context) do
    render_table_rows(table.rows) |> Enum.join("\n")
  end

  defp render_by_type(%CodeBlock{} = code_block, :content, _context) do
    begin_line = "#+BEGIN_SRC #{code_block.lang} #{code_block.details}" |> String.trim()
    ([begin_line] ++ code_block.lines ++ ["#+END_SRC"]) |> Enum.join("\n")
  end

  defp render_by_type(formatted_text, :text, _context) when is_list(formatted_text) do
    Enum.map_join(formatted_text, "", &Org.FormattedText.to_org_string/1)
  end

  defp render_by_type(text, :line, context) do
    indent = String.duplicate(" ", context.indent_level || 0)
    "#{indent}#{String.trim(text)}"
  end

  defp render_by_type(content, _type, _context) do
    to_string(content)
  end

  # Helper functions for rendering

  defp render_list_items(items, base_indent) do
    Enum.flat_map(items, fn item ->
      render_list_item(item, base_indent)
    end)
  end

  defp render_list_item(%List.Item{} = item, base_indent) do
    indent_str = String.duplicate("  ", base_indent + item.indent)

    bullet =
      if item.ordered do
        "#{item.number || 1}."
      else
        "-"
      end

    lines = ["#{indent_str}#{bullet} #{item.content}"]

    if item.children != [] do
      lines ++ render_list_items(item.children, base_indent + item.indent + 1)
    else
      lines
    end
  end

  defp render_table_rows(rows) do
    Enum.map(rows, fn
      %Table.Row{cells: cells} ->
        "| " <> Enum.join(cells, " | ") <> " |"

      %Table.Separator{} ->
        "|" <> String.duplicate("-", 10) <> "|"
    end)
  end

  defp normalize_keyword(""), do: nil
  defp normalize_keyword(keyword) when is_binary(keyword), do: keyword

  defp normalize_string(str) when is_binary(str), do: String.trim(str)
end
