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
      iex> child = Org.NodeFinder.find_by_path(doc, ["B", "Child"])
      iex> child.title
      "Child"
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
      "* Test"
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
    tags_part = render_section_tags_from_struct(section)
    header = "#{stars}#{todo_part}#{priority_part} #{section.title}#{tags_part}"

    lines = [header]

    # Add property drawer
    lines = lines ++ Org.PropertyDrawer.render_properties(section.properties)

    # Add planning metadata (SCHEDULED, DEADLINE, CLOSED)
    lines = lines ++ Org.PropertyDrawer.render_metadata(section.metadata)

    # Add contents
    lines = lines ++ contents_to_lines(section.contents)

    # Add children sections
    lines = lines ++ sections_to_lines(section.children, level + 1)

    lines
  end

  # Handle Section structs with inherited_tags field
  defp render_section_tags_from_struct(%Org.Section{tags: [], inherited_tags: []}), do: ""

  defp render_section_tags_from_struct(%Org.Section{tags: tags, inherited_tags: inherited_tags}) do
    # Get direct tags (tags that are not inherited)
    direct_tags = tags -- inherited_tags

    # Build tag representation showing inheritance
    inherited_part = if inherited_tags != [], do: Enum.map(inherited_tags, &"(#{&1})"), else: []
    direct_part = direct_tags

    # Combine inherited (in parentheses) and direct tags
    all_tag_parts = inherited_part ++ direct_part

    if all_tag_parts == [] do
      ""
    else
      tags_string = all_tag_parts |> Enum.join(":")
      " :#{tags_string}:"
    end
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

  # ============================================================================
  # Planning Metadata Functions
  # ============================================================================

  @doc """
  Adds or updates a SCHEDULED timestamp for a section.

  ## Examples

      iex> doc = Org.Parser.parse("* Task")
      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon 09:00>")
      iex> doc = Org.Writer.schedule(doc, ["Task"], timestamp)
      iex> task = Org.section(doc, ["Task"])
      iex> task.metadata.scheduled.date
      ~D[2024-01-15]
  """
  @spec schedule(Org.Document.t(), [String.t()], Org.Timestamp.t()) :: Org.Document.t()
  def schedule(doc, path, %Org.Timestamp{} = timestamp) do
    update_node(doc, path, fn
      %Org.Section{} = section ->
        updated_metadata = Map.put(section.metadata, :scheduled, timestamp)
        %{section | metadata: updated_metadata}

      node ->
        node
    end)
  end

  @doc """
  Adds or updates a DEADLINE timestamp for a section.

  ## Examples

      iex> doc = Org.Parser.parse("* Task")
      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-20 Sat>")
      iex> doc = Org.Writer.deadline(doc, ["Task"], timestamp)
      iex> task = Org.section(doc, ["Task"])
      iex> task.metadata.deadline.date
      ~D[2024-01-20]
  """
  @spec deadline(Org.Document.t(), [String.t()], Org.Timestamp.t()) :: Org.Document.t()
  def deadline(doc, path, %Org.Timestamp{} = timestamp) do
    update_node(doc, path, fn
      %Org.Section{} = section ->
        updated_metadata = Map.put(section.metadata, :deadline, timestamp)
        %{section | metadata: updated_metadata}

      node ->
        node
    end)
  end

  @doc """
  Adds or updates a CLOSED timestamp for a section (typically when marking as DONE).

  ## Examples

      iex> doc = Org.Parser.parse("* TODO Task")
      iex> {:ok, timestamp} = Org.Timestamp.parse("[2024-01-18 Thu 14:30]")
      iex> doc = Org.Writer.close_task(doc, ["Task"], timestamp)
      iex> task = Org.section(doc, ["Task"])
      iex> task.metadata.closed.date
      ~D[2024-01-18]
  """
  @spec close_task(Org.Document.t(), [String.t()], Org.Timestamp.t()) :: Org.Document.t()
  def close_task(doc, path, %Org.Timestamp{} = timestamp) do
    update_node(doc, path, fn
      %Org.Section{} = section ->
        updated_metadata = Map.put(section.metadata, :closed, timestamp)
        %{section | metadata: updated_metadata}

      node ->
        node
    end)
  end

  @doc """
  Removes SCHEDULED timestamp from a section.

  ## Examples

      iex> doc = Org.Parser.parse("* Task\\n  SCHEDULED: <2024-01-15 Mon>")
      iex> doc = Org.Writer.unschedule(doc, ["Task"])
      iex> task = Org.section(doc, ["Task"])
      iex> Map.get(task.metadata, :scheduled)
      nil
  """
  @spec unschedule(Org.Document.t(), [String.t()]) :: Org.Document.t()
  def unschedule(doc, path) do
    update_node(doc, path, fn
      %Org.Section{} = section ->
        updated_metadata = Map.delete(section.metadata, :scheduled)
        %{section | metadata: updated_metadata}

      node ->
        node
    end)
  end

  @doc """
  Removes DEADLINE timestamp from a section.
  """
  @spec remove_deadline(Org.Document.t(), [String.t()]) :: Org.Document.t()
  def remove_deadline(doc, path) do
    update_node(doc, path, fn
      %Org.Section{} = section ->
        updated_metadata = Map.delete(section.metadata, :deadline)
        %{section | metadata: updated_metadata}

      node ->
        node
    end)
  end

  @doc """
  Creates a new section with scheduling information in one call.

  ## Examples

      iex> doc = Org.Parser.parse("* Parent")
      iex> {:ok, scheduled} = Org.Timestamp.parse("<2024-01-15 Mon 09:00>")
      iex> {:ok, deadline} = Org.Timestamp.parse("<2024-01-20 Sat>")
      iex> doc = Org.Writer.add_scheduled_section(doc, ["Parent"], "Important Task", "TODO", "A", scheduled, deadline)
      iex> task = Org.section(doc, ["Parent", "Important Task"])
      iex> task.todo_keyword
      "TODO"
      iex> task.priority
      "A"
      iex> task.metadata.scheduled.date
      ~D[2024-01-15]
  """
  @spec add_scheduled_section(
          Org.Document.t(),
          [String.t()],
          String.t(),
          String.t() | nil,
          String.t() | nil,
          Org.Timestamp.t() | nil,
          Org.Timestamp.t() | nil
        ) :: Org.Document.t()
  def add_scheduled_section(doc, path, title, todo_keyword \\ nil, priority \\ nil, scheduled \\ nil, deadline \\ nil) do
    metadata = %{}
    metadata = if scheduled, do: Map.put(metadata, :scheduled, scheduled), else: metadata
    metadata = if deadline, do: Map.put(metadata, :deadline, deadline), else: metadata

    update_node(doc, path, fn
      %Org.Section{} = section ->
        new_child = %Org.Section{
          title: title,
          todo_keyword: todo_keyword,
          priority: priority,
          metadata: metadata,
          children: [],
          contents: []
        }

        %{section | children: section.children ++ [new_child]}

      node ->
        node
    end)
  end

  @doc """
  Updates multiple planning fields at once.

  ## Examples

      iex> doc = Org.Parser.parse("* Task")
      iex> {:ok, scheduled} = Org.Timestamp.parse("<2024-01-15 Mon>")
      iex> {:ok, deadline} = Org.Timestamp.parse("<2024-01-20 Sat>")
      iex> planning = %{scheduled: scheduled, deadline: deadline}
      iex> doc = Org.Writer.update_planning(doc, ["Task"], planning)
      iex> task = Org.section(doc, ["Task"])
      iex> task.metadata.scheduled.date
      ~D[2024-01-15]
      iex> task.metadata.deadline.date
      ~D[2024-01-20]
  """
  @spec update_planning(Org.Document.t(), [String.t()], map()) :: Org.Document.t()
  def update_planning(doc, path, planning) when is_map(planning) do
    update_node(doc, path, fn
      %Org.Section{} = section ->
        updated_metadata = Map.merge(section.metadata, planning)
        %{section | metadata: updated_metadata}

      node ->
        node
    end)
  end

  @doc """
  Marks a task as DONE and adds a CLOSED timestamp.
  For repeating tasks, advances the scheduled/deadline timestamps to the next occurrence.

  ## Examples

      iex> doc = Org.Parser.parse("* TODO Task")
      iex> now = DateTime.utc_now()
      iex> doc = Org.Writer.complete_task(doc, ["Task"], now)
      iex> task = Org.section(doc, ["Task"])
      iex> task.todo_keyword
      "DONE"
      iex> task.metadata.closed != nil
      true
  """
  @spec complete_task(Org.Document.t(), [String.t()], DateTime.t() | nil) :: Org.Document.t()
  def complete_task(doc, path, completion_time \\ nil) do
    completion_time = completion_time || DateTime.utc_now()

    # Create closed timestamp
    date = DateTime.to_date(completion_time)
    time = DateTime.to_time(completion_time)
    day_name = Date.day_of_week(date) |> day_number_to_name()

    closed_timestamp = %Org.Timestamp{
      type: :inactive,
      date: date,
      start_time: time,
      day_name: day_name,
      raw: "[#{Date.to_string(date)} #{day_name} #{Time.to_string(time) |> String.slice(0..4)}]"
    }

    update_node(doc, path, fn
      %Org.Section{} = section ->
        # Handle repeating tasks - advance timestamps and reset to TODO
        {updated_metadata, final_keyword} = handle_repeater_completion(section.metadata)

        # Always add CLOSED timestamp for this completion
        updated_metadata = Map.put(updated_metadata, :closed, closed_timestamp)

        %{section | todo_keyword: final_keyword, metadata: updated_metadata}

      node ->
        node
    end)
  end

  # Helper function to convert day numbers to names
  defp day_number_to_name(1), do: "Mon"
  defp day_number_to_name(2), do: "Tue"
  defp day_number_to_name(3), do: "Wed"
  defp day_number_to_name(4), do: "Thu"
  defp day_number_to_name(5), do: "Fri"
  defp day_number_to_name(6), do: "Sat"
  defp day_number_to_name(7), do: "Sun"

  # ============================================================================
  # Workflow Management Functions
  # ============================================================================

  @type todo_sequence :: %{
          active: [String.t()],
          done: [String.t()]
        }

  @type workflow_config :: %{
          sequences: [todo_sequence()],
          default_sequence: todo_sequence()
        }

  @doc """
  Creates a TODO workflow sequence configuration.

  ## Examples

      iex> workflow = Org.Writer.create_todo_sequence(["TODO", "DOING"], ["DONE"])
      iex> workflow.active
      ["TODO", "DOING"]
      iex> workflow.done
      ["DONE"]
  """
  @spec create_todo_sequence([String.t()], [String.t()]) :: todo_sequence()
  def create_todo_sequence(active_states, done_states) do
    %{active: active_states, done: done_states}
  end

  @doc """
  Creates a comprehensive workflow configuration with multiple sequences.

  ## Examples

      iex> basic = Org.Writer.create_todo_sequence(["TODO"], ["DONE"])
      iex> dev = Org.Writer.create_todo_sequence(["TODO", "INPROGRESS", "REVIEW"], ["DONE", "CANCELLED"])
      iex> config = Org.Writer.create_workflow_config([basic, dev], basic)
      iex> length(config.sequences)
      2
  """
  @spec create_workflow_config([todo_sequence()], todo_sequence()) :: workflow_config()
  def create_workflow_config(sequences, default_sequence) do
    %{sequences: sequences, default_sequence: default_sequence}
  end

  @doc """
  Gets the default workflow configuration (TODO -> DONE).

  ## Examples

      iex> config = Org.Writer.default_workflow_config()
      iex> config.default_sequence.active
      ["TODO"]
      iex> config.default_sequence.done
      ["DONE"]
  """
  @spec default_workflow_config() :: workflow_config()
  def default_workflow_config do
    default_sequence = create_todo_sequence(["TODO"], ["DONE"])
    create_workflow_config([default_sequence], default_sequence)
  end

  @doc """
  Cycles a TODO keyword to the next state in its workflow sequence.

  ## Examples

      iex> doc = Org.Parser.parse("* TODO Task")
      iex> doc = Org.Writer.cycle_todo(doc, ["Task"])
      iex> task = Org.section(doc, ["Task"])
      iex> task.todo_keyword
      "DONE"

      iex> doc = Org.Parser.parse("* DONE Task")
      iex> doc = Org.Writer.cycle_todo(doc, ["Task"])
      iex> task = Org.section(doc, ["Task"])
      iex> task.todo_keyword
      nil
  """
  @spec cycle_todo(Org.Document.t(), [String.t()], workflow_config() | nil) :: Org.Document.t()
  def cycle_todo(doc, path, workflow_config \\ nil) do
    workflow_config = workflow_config || default_workflow_config()

    update_node(doc, path, fn
      %Org.Section{} = section ->
        next_keyword = get_next_todo_state(section.todo_keyword, workflow_config)
        %{section | todo_keyword: next_keyword}

      node ->
        node
    end)
  end

  @doc """
  Cycles a TODO keyword backwards to the previous state in its workflow sequence.

  ## Examples

      iex> doc = Org.Parser.parse("* DONE Task")
      iex> doc = Org.Writer.cycle_todo_backward(doc, ["Task"])
      iex> task = Org.section(doc, ["Task"])
      iex> task.todo_keyword
      "TODO"
  """
  @spec cycle_todo_backward(Org.Document.t(), [String.t()], workflow_config() | nil) :: Org.Document.t()
  def cycle_todo_backward(doc, path, workflow_config \\ nil) do
    workflow_config = workflow_config || default_workflow_config()

    update_node(doc, path, fn
      %Org.Section{} = section ->
        prev_keyword = get_previous_todo_state(section.todo_keyword, workflow_config)
        %{section | todo_keyword: prev_keyword}

      node ->
        node
    end)
  end

  @doc """
  Sets a specific TODO keyword on a section.

  ## Examples

      iex> doc = Org.Parser.parse("* Task")
      iex> doc = Org.Writer.set_todo_keyword(doc, ["Task"], "TODO")
      iex> task = Org.section(doc, ["Task"])
      iex> task.todo_keyword
      "TODO"
  """
  @spec set_todo_keyword(Org.Document.t(), [String.t()], String.t() | nil) :: Org.Document.t()
  def set_todo_keyword(doc, path, keyword) do
    update_node(doc, path, fn
      %Org.Section{} = section ->
        %{section | todo_keyword: keyword}

      node ->
        node
    end)
  end

  @doc """
  Removes TODO keyword from a section (sets it to nil).

  ## Examples

      iex> doc = Org.Parser.parse("* TODO Task")
      iex> doc = Org.Writer.clear_todo_keyword(doc, ["Task"])
      iex> task = Org.section(doc, ["Task"])
      iex> task.todo_keyword
      nil
  """
  @spec clear_todo_keyword(Org.Document.t(), [String.t()]) :: Org.Document.t()
  def clear_todo_keyword(doc, path) do
    set_todo_keyword(doc, path, nil)
  end

  # Helper functions for TODO workflow cycling

  defp get_next_todo_state(current_keyword, workflow_config) do
    sequence = find_sequence_for_keyword(current_keyword, workflow_config)

    case current_keyword do
      nil ->
        get_initial_todo_state(workflow_config)

      keyword ->
        get_next_state_for_keyword(keyword, sequence)
    end
  end

  defp get_initial_todo_state(workflow_config) do
    # No current keyword, start with first active state of default sequence
    # If no active states, start with first done state
    List.first(workflow_config.default_sequence.active) ||
      List.first(workflow_config.default_sequence.done)
  end

  defp get_next_state_for_keyword(keyword, %{active: active, done: done}) do
    case find_keyword_in_states(keyword, active, done) do
      {:active, index} ->
        advance_in_active_states(index, active, done)

      {:done, index} ->
        advance_in_done_states(index, done)

      :unknown ->
        # Unknown keyword, start with first active state or first done state if no active
        List.first(active) || List.first(done)
    end
  end

  defp find_keyword_in_states(keyword, active, done) do
    case Enum.find_index(active, &(&1 == keyword)) do
      nil ->
        case Enum.find_index(done, &(&1 == keyword)) do
          nil -> :unknown
          index -> {:done, index}
        end

      index ->
        {:active, index}
    end
  end

  defp advance_in_active_states(index, active, done) do
    if index + 1 < length(active) do
      Enum.at(active, index + 1)
    else
      List.first(done)
    end
  end

  defp advance_in_done_states(index, done) do
    if index + 1 < length(done) do
      Enum.at(done, index + 1)
    else
      nil
    end
  end

  defp get_previous_todo_state(current_keyword, workflow_config) do
    sequence = find_sequence_for_keyword(current_keyword, workflow_config)

    case current_keyword do
      nil ->
        get_initial_previous_todo_state(workflow_config)

      keyword ->
        get_previous_state_for_keyword(keyword, sequence)
    end
  end

  defp get_initial_previous_todo_state(workflow_config) do
    # No current keyword, start with last done state of default sequence
    List.last(workflow_config.default_sequence.done)
  end

  defp get_previous_state_for_keyword(keyword, %{active: active, done: done}) do
    case find_keyword_in_states(keyword, active, done) do
      {:active, 0} ->
        # First active state, cycle to nil
        nil

      {:active, index} ->
        # In active states, move to previous active state
        Enum.at(active, index - 1)

      {:done, 0} ->
        # First done state, go to last active state
        List.last(active)

      {:done, index} ->
        # In done states, go to previous done state
        Enum.at(done, index - 1)

      :unknown ->
        # Unknown keyword, start with last done state
        List.last(done)
    end
  end

  defp find_sequence_for_keyword(keyword, workflow_config) do
    Enum.find(workflow_config.sequences, fn %{active: active, done: done} ->
      keyword in active or keyword in done
    end) || workflow_config.default_sequence
  end

  @doc """
  Checks if a keyword represents a "done" state in any workflow sequence.

  ## Examples

      iex> config = Org.Writer.default_workflow_config()
      iex> Org.Writer.todo_keyword_done?("DONE", config)
      true
      iex> Org.Writer.todo_keyword_done?("TODO", config)
      false
  """
  @spec todo_keyword_done?(String.t() | nil, workflow_config()) :: boolean()
  def todo_keyword_done?(nil, _config), do: false

  def todo_keyword_done?(keyword, workflow_config) do
    Enum.any?(workflow_config.sequences, fn %{done: done} ->
      keyword in done
    end)
  end

  @doc """
  Checks if a keyword represents an "active" state in any workflow sequence.

  ## Examples

      iex> config = Org.Writer.default_workflow_config()
      iex> Org.Writer.todo_keyword_active?("TODO", config)
      true
      iex> Org.Writer.todo_keyword_active?("DONE", config)
      false
  """
  @spec todo_keyword_active?(String.t() | nil, workflow_config()) :: boolean()
  def todo_keyword_active?(nil, _config), do: false

  def todo_keyword_active?(keyword, workflow_config) do
    Enum.any?(workflow_config.sequences, fn %{active: active} ->
      keyword in active
    end)
  end

  @doc """
  Gets all possible TODO keywords from a workflow configuration.

  ## Examples

      iex> config = Org.Writer.default_workflow_config()
      iex> keywords = Org.Writer.all_todo_keywords(config)
      iex> "TODO" in keywords
      true
      iex> "DONE" in keywords
      true
  """
  @spec all_todo_keywords(workflow_config()) :: [String.t()]
  def all_todo_keywords(workflow_config) do
    workflow_config.sequences
    |> Enum.flat_map(fn %{active: active, done: done} -> active ++ done end)
    |> Enum.uniq()
  end

  # ============================================================================
  # Repeater Handling Functions
  # ============================================================================

  @doc """
  Completes a repeating task by advancing its timestamps to the next occurrence
  and resetting its TODO state.

  ## Examples

      iex> doc = Org.Parser.parse("* TODO Weekly Meeting\\n  SCHEDULED: <2024-01-15 Mon 09:00 +1w>")
      iex> doc = Org.Writer.complete_repeating_task(doc, ["Weekly Meeting"])
      iex> task = Org.section(doc, ["Weekly Meeting"])
      iex> task.todo_keyword
      "TODO"
      iex> task.metadata.scheduled.date
      ~D[2024-01-22]
  """
  @spec complete_repeating_task(Org.Document.t(), [String.t()], DateTime.t() | nil) :: Org.Document.t()
  def complete_repeating_task(doc, path, completion_time \\ nil) do
    completion_time = completion_time || DateTime.utc_now()

    update_node(doc, path, fn
      %Org.Section{} = section ->
        # Check if this is actually a repeating task
        has_repeater = has_repeating_timestamps?(section.metadata)

        if has_repeater do
          # Advance repeaters and reset to TODO
          {updated_metadata, _} = handle_repeater_completion(section.metadata)
          %{section | todo_keyword: "TODO", metadata: updated_metadata}
        else
          # Not a repeating task, complete normally
          complete_non_repeating_task(section, completion_time)
        end

      node ->
        node
    end)
  end

  @doc """
  Advances all repeating timestamps in a section to their next occurrences.

  ## Examples

      iex> doc = Org.Parser.parse("* Task\\n  SCHEDULED: <2024-01-15 Mon +1w>")
      iex> doc = Org.Writer.advance_repeaters(doc, ["Task"])
      iex> task = Org.section(doc, ["Task"])
      iex> task.metadata.scheduled.date
      ~D[2024-01-22]
  """
  @spec advance_repeaters(Org.Document.t(), [String.t()]) :: Org.Document.t()
  def advance_repeaters(doc, path) do
    update_node(doc, path, fn
      %Org.Section{} = section ->
        updated_metadata = advance_all_repeating_timestamps(section.metadata)
        %{section | metadata: updated_metadata}

      node ->
        node
    end)
  end

  @doc """
  Checks if a section has any repeating timestamps.

  ## Examples

      iex> doc = Org.Parser.parse("* Task\\n  SCHEDULED: <2024-01-15 Mon +1w>")
      iex> task = Org.section(doc, ["Task"])
      iex> Org.Writer.has_repeating_timestamps?(task.metadata)
      true
  """
  @spec has_repeating_timestamps?(map()) :: boolean()
  def has_repeating_timestamps?(metadata) do
    Enum.any?([:scheduled, :deadline, :closed], fn key ->
      case Map.get(metadata, key) do
        %Org.Timestamp{repeater: %{}} -> true
        _ -> false
      end
    end)
  end

  @doc """
  Sets a repeating scheduled timestamp for a section.

  ## Examples

      iex> doc = Org.Parser.parse("* Task")
      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon 09:00 +1w>")
      iex> doc = Org.Writer.schedule_repeating(doc, ["Task"], timestamp)
      iex> task = Org.section(doc, ["Task"])
      iex> Org.Timestamp.repeating?(task.metadata.scheduled)
      true
  """
  @spec schedule_repeating(Org.Document.t(), [String.t()], Org.Timestamp.t()) :: Org.Document.t()
  def schedule_repeating(doc, path, %Org.Timestamp{repeater: %{}} = timestamp) do
    schedule(doc, path, timestamp)
  end

  def schedule_repeating(_doc, _path, %Org.Timestamp{repeater: nil}) do
    raise ArgumentError, "Timestamp must have a repeater"
  end

  @doc """
  Sets a repeating deadline timestamp for a section.
  """
  @spec deadline_repeating(Org.Document.t(), [String.t()], Org.Timestamp.t()) :: Org.Document.t()
  def deadline_repeating(doc, path, %Org.Timestamp{repeater: %{}} = timestamp) do
    deadline(doc, path, timestamp)
  end

  def deadline_repeating(_doc, _path, %Org.Timestamp{repeater: nil}) do
    raise ArgumentError, "Timestamp must have a repeater"
  end

  # Private helper functions for repeater handling

  defp handle_repeater_completion(metadata) do
    has_repeater = has_repeating_timestamps?(metadata)

    if has_repeater do
      # Advance all repeating timestamps to next occurrence
      updated_metadata = advance_all_repeating_timestamps(metadata)
      # Reset to TODO since task repeats
      {updated_metadata, "TODO"}
    else
      # No repeaters, complete normally
      {metadata, "DONE"}
    end
  end

  defp advance_all_repeating_timestamps(metadata) do
    metadata
    |> advance_timestamp_if_repeating(:scheduled)
    |> advance_timestamp_if_repeating(:deadline)
    |> advance_timestamp_if_repeating(:closed)
  end

  defp advance_timestamp_if_repeating(metadata, key) do
    case Map.get(metadata, key) do
      %Org.Timestamp{repeater: %{}} = timestamp ->
        next_occurrence = Org.Timestamp.next_occurrence(timestamp)
        Map.put(metadata, key, next_occurrence)

      _ ->
        metadata
    end
  end

  defp complete_non_repeating_task(section, completion_time) do
    # Create closed timestamp
    date = DateTime.to_date(completion_time)
    time = DateTime.to_time(completion_time)
    day_name = Date.day_of_week(date) |> day_number_to_name()

    closed_timestamp = %Org.Timestamp{
      type: :inactive,
      date: date,
      start_time: time,
      day_name: day_name,
      raw: "[#{Date.to_string(date)} #{day_name} #{Time.to_string(time) |> String.slice(0..4)}]"
    }

    updated_metadata = Map.put(section.metadata, :closed, closed_timestamp)
    %{section | todo_keyword: "DONE", metadata: updated_metadata}
  end
end
