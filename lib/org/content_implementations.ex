defimpl Org.Content, for: Org.Paragraph do
  def content_type(_), do: :paragraph

  def reverse_recursive(paragraph) do
    %{paragraph | lines: Enum.reverse(paragraph.lines)}
  end

  def can_merge?(_paragraph, %Org.Paragraph{}) do
    # Don't merge paragraphs - they should only be merged within the same continuous text block
    # Empty lines should create separate paragraphs
    false
  end

  def can_merge?(_, _), do: false

  def merge(%Org.Paragraph{lines: lines1}, %Org.Paragraph{lines: lines2}) do
    # Merge paragraphs with a blank line separator
    %Org.Paragraph{lines: lines1 ++ [""] ++ lines2}
  end

  def validate(%Org.Paragraph{lines: lines}) when is_list(lines) do
    if Enum.all?(lines, &is_binary/1) do
      {:ok, %Org.Paragraph{lines: lines}}
    else
      {:error, "All paragraph lines must be strings"}
    end
  end

  def validate(_), do: {:error, "Invalid paragraph structure"}

  def to_text(%Org.Paragraph{lines: lines}) do
    Enum.join(lines, "\n")
  end

  def metadata(%Org.Paragraph{lines: lines}) do
    %{
      line_count: length(lines),
      character_count: lines |> Enum.join("\n") |> String.length(),
      word_count: lines |> Enum.join(" ") |> String.split() |> length()
    }
  end

  def empty?(%Org.Paragraph{lines: lines}) do
    lines == [] or Enum.all?(lines, fn line -> String.trim(line) == "" end)
  end
end

defimpl Org.Content, for: Org.Table do
  def content_type(_), do: :table

  def reverse_recursive(table) do
    %{table | rows: Enum.reverse(table.rows)}
  end

  def can_merge?(%Org.Table{}, %Org.Table{}) do
    # Tables can potentially be merged
    true
  end

  def can_merge?(_, _), do: false

  def merge(%Org.Table{rows: rows1}, %Org.Table{rows: rows2}) do
    # Merge tables by combining rows
    %Org.Table{rows: rows1 ++ rows2}
  end

  def validate(%Org.Table{rows: rows}) when is_list(rows) do
    valid_rows =
      Enum.all?(rows, fn
        %Org.Table.Row{cells: cells} when is_list(cells) ->
          Enum.all?(cells, &is_binary/1)

        %Org.Table.Separator{} ->
          true

        _ ->
          false
      end)

    if valid_rows do
      {:ok, %Org.Table{rows: rows}}
    else
      {:error, "Invalid table row structure"}
    end
  end

  def validate(_), do: {:error, "Invalid table structure"}

  def to_text(%Org.Table{rows: rows}) do
    Enum.map_join(rows, "\n", fn
      %Org.Table.Row{cells: cells} -> Enum.join(cells, " | ")
      %Org.Table.Separator{} -> "---"
    end)
  end

  def metadata(%Org.Table{rows: rows}) do
    data_rows = Enum.filter(rows, &match?(%Org.Table.Row{}, &1))
    separator_count = length(rows) - length(data_rows)

    %{
      total_rows: length(rows),
      data_rows: length(data_rows),
      separator_rows: separator_count,
      max_columns: data_rows |> Enum.map(fn %{cells: cells} -> length(cells) end) |> Enum.max(fn -> 0 end)
    }
  end

  def empty?(%Org.Table{rows: []}), do: true

  def empty?(%Org.Table{rows: rows}) do
    Enum.all?(rows, fn
      %Org.Table.Row{cells: cells} -> Enum.all?(cells, fn cell -> String.trim(cell) == "" end)
      # Separators are not "empty"
      %Org.Table.Separator{} -> false
    end)
  end
end

defimpl Org.Content, for: Org.CodeBlock do
  def content_type(_), do: :code_block

  def reverse_recursive(code_block) do
    %{code_block | lines: Enum.reverse(code_block.lines)}
  end

  def can_merge?(_, _) do
    # Code blocks typically shouldn't be merged
    false
  end

  def merge(_, _) do
    raise "Code blocks cannot be merged"
  end

  def validate(%Org.CodeBlock{lang: lang, details: details, lines: lines})
      when is_binary(lang) and is_binary(details) and is_list(lines) do
    if Enum.all?(lines, &is_binary/1) do
      {:ok, %Org.CodeBlock{lang: lang, details: details, lines: lines}}
    else
      {:error, "All code block lines must be strings"}
    end
  end

  def validate(_), do: {:error, "Invalid code block structure"}

  def to_text(%Org.CodeBlock{lines: lines}) do
    Enum.join(lines, "\n")
  end

  def metadata(%Org.CodeBlock{lang: lang, details: details, lines: lines}) do
    %{
      language: lang,
      details: details,
      line_count: length(lines),
      character_count: lines |> Enum.join("\n") |> String.length()
    }
  end

  def empty?(%Org.CodeBlock{lines: lines}) do
    lines == [] or Enum.all?(lines, fn line -> String.trim(line) == "" end)
  end
end

defimpl Org.Content, for: Org.List do
  def content_type(_), do: :list

  def reverse_recursive(list) do
    reversed_items =
      list.items
      |> Enum.reverse()
      |> Enum.map(&reverse_list_item/1)

    %{list | items: reversed_items}
  end

  def can_merge?(%Org.List{}, %Org.List{}) do
    # Lists can potentially be merged if they're compatible
    true
  end

  def can_merge?(_, _), do: false

  def merge(%Org.List{items: items1}, %Org.List{items: items2}) do
    # Merge lists by combining items
    %Org.List{items: items1 ++ items2}
  end

  def validate(%Org.List{items: items}) when is_list(items) do
    valid_items = Enum.all?(items, &valid_list_item?/1)

    if valid_items do
      {:ok, %Org.List{items: items}}
    else
      {:error, "Invalid list item structure"}
    end
  end

  def validate(_), do: {:error, "Invalid list structure"}

  def to_text(%Org.List{items: items}) do
    Enum.map_join(items, "\n", &list_item_to_text(&1, 0))
  end

  def metadata(%Org.List{items: items}) do
    flat_items = flatten_list_items(items)

    %{
      total_items: length(flat_items),
      top_level_items: length(items),
      max_depth: calculate_max_depth(items, 0),
      ordered_items: flat_items |> Enum.count(& &1.ordered),
      unordered_items: flat_items |> Enum.count(&(not &1.ordered))
    }
  end

  def empty?(%Org.List{items: []}), do: true

  def empty?(%Org.List{items: items}) do
    Enum.all?(items, fn item ->
      String.trim(item.content) == "" and Enum.empty?(item.children)
    end)
  end

  # Private helper functions

  defp reverse_list_item(%Org.List.Item{children: children} = item) do
    %{item | children: Enum.reverse(children) |> Enum.map(&reverse_list_item/1)}
  end

  defp valid_list_item?(%Org.List.Item{
         content: content,
         indent: indent,
         ordered: ordered,
         number: number,
         children: children
       })
       when is_binary(content) and is_integer(indent) and is_boolean(ordered) and is_list(children) do
    (number == nil or is_integer(number)) and Enum.all?(children, &valid_list_item?/1)
  end

  defp valid_list_item?(_), do: false

  defp list_item_to_text(%Org.List.Item{content: content, children: children}, depth) do
    prefix = String.duplicate("  ", depth)
    item_text = "#{prefix}- #{content}"

    children_text = Enum.map_join(children, "\n", &list_item_to_text(&1, depth + 1))

    if children_text == "" do
      item_text
    else
      item_text <> "\n" <> children_text
    end
  end

  defp flatten_list_items(items) do
    Enum.flat_map(items, fn item ->
      [item | flatten_list_items(item.children)]
    end)
  end

  defp calculate_max_depth([], current_depth), do: current_depth

  defp calculate_max_depth(items, current_depth) do
    if Enum.all?(items, fn item -> Enum.empty?(item.children) end) do
      current_depth
    else
      items
      |> Enum.map(fn item -> calculate_max_depth(item.children, current_depth + 1) end)
      |> Enum.max(fn -> current_depth end)
    end
  end
end
