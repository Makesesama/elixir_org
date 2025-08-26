defmodule Org.Writer do
  @moduledoc """
  Provides functionality to modify and write Org documents.

  This module allows you to:
  - Add sections and content to documents
  - Update existing nodes
  - Remove nodes from the tree
  - Serialize documents back to org-mode text format
  """

  alias Org.NodeFinder

  @doc """
  Adds a new section under the specified parent path.

  ## Examples

      iex> doc = Org.Parser.parse("* Parent")
      iex> doc = Org.Writer.add_section(doc, ["Parent"], "Child", "TODO", "A")
      iex> child = Org.NodeFinder.find_by_path(doc, ["Parent", "Child"])
      iex> child.title
      "Child"
  """
  def add_section(doc, path, title, todo_keyword \\ nil, priority \\ nil)

  def add_section(%Org.Document{} = doc, [], title, todo_keyword, priority) do
    new_section = %Org.Section{
      title: title,
      todo_keyword: todo_keyword,
      priority: priority,
      children: [],
      contents: []
    }

    %{doc | sections: doc.sections ++ [new_section]}
  end

  def add_section(%Org.Document{} = doc, path, title, todo_keyword, priority) do
    update_node(doc, path, fn
      %Org.Section{} = section ->
        new_child = %Org.Section{
          title: title,
          todo_keyword: todo_keyword,
          priority: priority,
          children: [],
          contents: []
        }

        %{section | children: section.children ++ [new_child]}

      _ ->
        raise ArgumentError, "Can only add sections to other sections"
    end)
  end

  @doc """
  Adds content (paragraph, table, code block, etc.) under the specified path.

  ## Examples

      iex> doc = Org.Parser.parse("* Section")
      iex> para = %Org.Paragraph{lines: ["New content"]}
      iex> doc = Org.Writer.add_content(doc, ["Section"], para)
      iex> contents = Org.NodeFinder.find_by_path(doc, ["Section"]).contents
      iex> length(contents)
      1
  """
  def add_content(%Org.Document{} = doc, [], content) do
    %{doc | contents: doc.contents ++ [content]}
  end

  def add_content(%Org.Document{} = doc, path, content) do
    update_node(doc, path, fn
      %Org.Section{} = section ->
        %{section | contents: section.contents ++ [content]}

      _ ->
        raise ArgumentError, "Can only add content to documents or sections"
    end)
  end

  @doc """
  Inserts a section at a specific position under the parent.

  Position can be:
  - An integer index (0-based)
  - `:first` to insert at the beginning
  - `:last` to insert at the end (same as add_section)
  - `:before, title` to insert before a specific sibling
  - `:after, title` to insert after a specific sibling
  """
  def insert_section(doc, path, position, title, todo_keyword \\ nil, priority \\ nil)

  def insert_section(%Org.Document{} = doc, path, position, title, todo_keyword, priority) do
    new_section = %Org.Section{
      title: title,
      todo_keyword: todo_keyword,
      priority: priority,
      children: [],
      contents: []
    }

    if path == [] do
      sections = insert_at_position(doc.sections, new_section, position)
      %{doc | sections: sections}
    else
      update_node(doc, path, fn
        %Org.Section{} = section ->
          children = insert_at_position(section.children, new_section, position)
          %{section | children: children}

        _ ->
          raise ArgumentError, "Can only insert sections under other sections"
      end)
    end
  end

  @doc """
  Updates a node at the specified path using the given function.

  The function receives the current node and should return the updated node.
  """
  def update_node(%Org.Document{} = doc, [], updater) when is_function(updater, 1) do
    updater.(doc)
  end

  def update_node(%Org.Document{} = doc, path, updater) when is_function(updater, 1) do
    update_node_recursive(doc, path, updater)
  end

  defp update_node_recursive(%Org.Document{sections: sections} = doc, [first | rest], updater) do
    updated_sections =
      Enum.map(sections, &update_matching_section(&1, first, rest, updater))

    %{doc | sections: updated_sections}
  end

  defp update_node_recursive(%Org.Section{children: children} = section, [first | rest], updater) do
    updated_children =
      Enum.map(children, &update_matching_section(&1, first, rest, updater))

    %{section | children: updated_children}
  end

  @doc """
  Removes a node at the specified path.

  ## Examples

      iex> doc = Org.Parser.parse("* Parent\\n** Child\\n** Another")
      iex> doc = Org.Writer.remove_node(doc, ["Parent", "Child"])
      iex> Org.NodeFinder.find_by_path(doc, ["Parent", "Child"])
      nil
  """
  def remove_node(%Org.Document{} = doc, [title]) do
    %{doc | sections: Enum.reject(doc.sections, fn s -> s.title == title end)}
  end

  def remove_node(%Org.Document{} = doc, path) do
    {parent_path, [node_title]} = Enum.split(path, -1)

    update_node(doc, parent_path, fn
      %Org.Section{} = section ->
        %{section | children: Enum.reject(section.children, fn c -> c.title == node_title end)}

      _ ->
        raise ArgumentError, "Invalid path for removal"
    end)
  end

  @doc """
  Moves a node from one location to another.

  ## Examples

      iex> doc = Org.Parser.parse("* A\\n** Child\\n* B")
      iex> doc = Org.Writer.move_node(doc, ["A", "Child"], ["B"])
      iex> Org.NodeFinder.find_by_path(doc, ["B", "Child"])
      %Org.Section{title: "Child", ...}
  """
  def move_node(%Org.Document{} = doc, from_path, to_path) do
    # Find the node to move
    node = NodeFinder.find_by_path(doc, from_path)

    if node do
      # Remove from current location
      doc = remove_node(doc, from_path)

      # Add to new location
      add_node_to_new_location(doc, node, to_path)
    else
      doc
    end
  end

  # Helper function to insert at specific positions
  defp insert_at_position(list, item, position) do
    case position do
      :first ->
        [item | list]

      :last ->
        list ++ [item]

      {:before, title} ->
        {before, after_with_target} =
          Enum.split_while(list, fn x ->
            get_title(x) != title
          end)

        before ++ [item | after_with_target]

      {:after, title} ->
        {before_with_target, after_rest} =
          Enum.split_while(list, fn x ->
            get_title(x) != title
          end)

        case after_rest do
          [] -> before_with_target ++ [item]
          _ -> before_with_target ++ [hd(after_rest), item | tl(after_rest)]
        end

      index when is_integer(index) ->
        {before, after_rest} = Enum.split(list, index)
        before ++ [item | after_rest]
    end
  end

  defp get_title(%Org.Section{title: title}), do: title
  defp get_title(_), do: nil

  @doc """
  Serializes an Org document back to org-mode text format.

  ## Examples

      iex> doc = %Org.Document{sections: [%Org.Section{title: "Test"}]}
      iex> Org.Writer.to_org_string(doc)
      "* Test\\n"
  """
  def to_org_string(%Org.Document{} = doc) do
    lines = []

    # Add file properties first
    lines = lines ++ Org.FileProperties.render_properties(doc.file_properties)

    # Add blank line after file properties if they exist
    lines = if doc.file_properties != %{}, do: lines ++ [""], else: lines

    # Add comments
    lines = lines ++ Enum.map(doc.comments, fn comment -> "##{comment}" end)

    # Add top-level contents
    lines = lines ++ contents_to_lines(doc.contents)

    # Add sections
    lines = lines ++ sections_to_lines(doc.sections, 1)

    Enum.join(lines, "\n")
  end

  defp sections_to_lines(sections, level) do
    Enum.flat_map(sections, fn section ->
      section_to_lines(section, level)
    end)
  end

  defp section_to_lines(%Org.Section{} = section, level) do
    # Build header line
    stars = String.duplicate("*", level)
    todo_part = if section.todo_keyword, do: " #{section.todo_keyword}", else: ""
    priority_part = if section.priority, do: " [##{section.priority}]", else: ""
    header = "#{stars}#{todo_part}#{priority_part} #{section.title}"

    lines = [header]

    # Add contents
    lines = lines ++ contents_to_lines(section.contents)

    # Add children sections
    lines = lines ++ sections_to_lines(section.children, level + 1)

    lines
  end

  defp contents_to_lines(contents) do
    Enum.flat_map(contents, &content_to_lines/1)
  end

  defp content_to_lines(%Org.Paragraph{lines: lines}) do
    formatted_lines =
      Enum.map(lines, fn
        %Org.FormattedText{} = formatted -> Org.FormattedText.to_org_string(formatted)
        line when is_binary(line) -> line
      end)

    # Add blank line after paragraph
    formatted_lines ++ [""]
  end

  defp content_to_lines(%Org.CodeBlock{lang: lang, details: details, lines: lines}) do
    begin_line = "#+BEGIN_SRC #{lang} #{details}" |> String.trim()
    ["#{begin_line}"] ++ lines ++ ["#+END_SRC", ""]
  end

  defp content_to_lines(%Org.Table{rows: rows}) do
    table_lines =
      Enum.map(rows, fn
        %Org.Table.Row{cells: cells} ->
          "| " <> Enum.join(cells, " | ") <> " |"

        %Org.Table.Separator{} ->
          "|" <> String.duplicate("-", 10) <> "|"
      end)

    table_lines ++ [""]
  end

  defp content_to_lines(%Org.List{items: items}) do
    list_to_lines(items, 0) ++ [""]
  end

  defp content_to_lines(_), do: []

  defp list_to_lines(items, base_indent) do
    Enum.flat_map(items, fn item ->
      item_to_lines(item, base_indent)
    end)
  end

  defp item_to_lines(%Org.List.Item{} = item, base_indent) do
    indent_str = String.duplicate("  ", base_indent + item.indent)

    bullet =
      if item.ordered do
        "#{item.number || 1}."
      else
        "-"
      end

    lines = ["#{indent_str}#{bullet} #{item.content}"]

    if item.children != [] do
      lines ++ list_to_lines(item.children, base_indent + item.indent + 1)
    else
      lines
    end
  end

  # Helper functions to reduce nesting depth

  defp update_matching_section(section, target_title, rest, updater) do
    if section.title == target_title do
      if rest == [] do
        updater.(section)
      else
        update_node_recursive(section, rest, updater)
      end
    else
      section
    end
  end

  defp add_node_to_new_location(doc, node, to_path) do
    case node do
      %Org.Section{} = section ->
        add_section(doc, to_path, section.title, section.todo_keyword, section.priority)
        |> update_node(to_path ++ [section.title], fn _ -> section end)

      content ->
        add_content(doc, to_path, content)
    end
  end
end
