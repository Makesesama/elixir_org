defmodule Org do
  @moduledoc """
  This package implements an org-mode lexer and parser.

  org-mode is the markup language used by the powerful [org mode package for emacs](http://orgmode.org/).

  This implementation supports only a small subset of the syntax at this point, but can already be useful for extracting information from well-formed documents.

  Features supported are:
  - Comments
  - (nested) Sections with TODO/DONE keywords and priorities
  - Paragraphs
  - Tables
  - Code blocks
  - Lists (ordered and unordered, with nesting support)

  ## TODO Keywords and Priorities

  Headlines can include TODO keywords (currently supports TODO and DONE) and priorities ([#A], [#B], [#C]):

      iex> doc = Org.load_string("* TODO [#A] Write documentation\\n** DONE [#B] Research\\n** Implementation")
      iex> section = hd(doc.sections)
      iex> section.todo_keyword
      "TODO"
      iex> section.priority
      "A"
      iex> for child <- section.children, do: {child.title, child.todo_keyword, child.priority}
      [{"Research", "DONE", "B"}, {"Implementation", nil, nil}]
  """

  @type load_mode :: :document | :tokens

  @doc "Loads a document from a file at given path"
  @spec load_file(String.t(), load_mode) :: Org.Document.t()
  def load_file(path, load_mode \\ :document) do
    {:ok, data} = File.read(path)
    load_string(data, load_mode)
  end

  @doc "Loads a document from the given source string"
  @spec load_string(String.t(), load_mode) :: Org.Document.t()
  def load_string(data, load_mode \\ :document)

  def load_string(data, :document) do
    Org.Parser.parse(data, mode: :flexible)
  end

  def load_string(data, :tokens) do
    Org.Lexer.lex(data)
  end

  @doc ~S"""
  Extracts a section at the given path of titles

  Example:
      iex> doc = Org.load_string(~S{
      ...>* First
      ...>** Second
      ...>*** Third
      ...>* Fourth
      ...>})
      iex> Org.section(doc, ["First"]).title
      "First"
      iex> Org.section(doc, ["First", "Second", "Third"]).title
      "Third"
      iex> Org.section(doc, ["Fourth"]).title
      "Fourth"
  """
  @spec section(Org.Document.t(), list(String.t())) :: Org.Section.t()
  def section(doc, path) do
    Org.Section.find_by_path(doc.sections, path)
  end

  @doc ~S"""
  Extracts all tables from the given section or document

  Example:
      iex> doc = Org.load_string(~S{
      ...>First paragraph
      ...>| x | y |
      ...>| 1 | 7 |
      ...>Second paragraph
      ...>})
      iex> Org.tables(doc)
      [%Org.Table{rows: [%Org.Table.Row{cells: ["x", "y"]}, %Org.Table.Row{cells: ["1", "7"]}]}]
  """
  @spec tables(Org.Section.t() | Org.Document.t()) :: list(Org.Table.t())
  def tables(section_or_document) do
    for %Org.Table{} = table <- Org.contents(section_or_document), do: table
  end

  @doc ~S"""
  Extracts all code blocks from the given section or document

  Example:
      iex> doc = Org.load_string(~S{
      ...>First example:
      ...>
      ...>#+BEGIN_SRC emacs-lisp -n 10
      ...>(message "Hello World!")
      ...>(message "...")
      ...>#+END_SRC
      ...>
      ...>Second example:
      ...>
      ...>#+BEGIN_SRC org-mode
      ...>* Nested document
      ...>This is a nested document.
      ...>
      ...>| With   | a      |
      ...>| nested | table. |
      ...>
      ...>It will not be parsed.
      ...>#+END_SRC
      ...>
      ...>})
      iex> Org.code_blocks(doc)
      [%Org.CodeBlock{lang: "emacs-lisp", details: "-n 10", lines: ["(message \"Hello World!\")", "(message \"...\")"]},
       %Org.CodeBlock{lang: "org-mode", details: "", lines: ["* Nested document", "This is a nested document.", "", "| With   | a      |", "| nested | table. |", "", "It will not be parsed."]}]
  """
  def code_blocks(section_or_document) do
    for %Org.CodeBlock{} = code_block <- Org.contents(section_or_document), do: code_block
  end

  @doc ~S"""
  Extracts all paragraphs from the given section or document

  Example:
      iex> doc = Org.load_string(~S{
      ...>First paragraph
      ...>| x | y |
      ...>| 1 | 7 |
      ...>Second paragraph
      ...>})
      iex> Org.paragraphs(doc)
      [%Org.Paragraph{lines: ["First paragraph"]}, %Org.Paragraph{lines: ["Second paragraph"]}]
  """
  @spec paragraphs(Org.Section.t() | Org.Document.t()) :: list(Org.Paragraph.t())
  def paragraphs(section_or_document) do
    for %Org.Paragraph{} = paragraph <- Org.contents(section_or_document), do: paragraph
  end

  @doc ~S"""
  Extracts all lists from the given section or document

  Example:
      iex> doc = Org.load_string(~S{
      ...>- First item
      ...>- Second item
      ...>  - Nested item
      ...>})
      iex> [list] = Org.lists(doc)
      iex> length(list.items)
      3
      iex> Enum.at(list.items, 0).content
      "First item"
      iex> Enum.at(list.items, 0).ordered
      false
  """
  @spec lists(Org.Section.t() | Org.Document.t()) :: list(Org.List.t())
  def lists(section_or_document) do
    for %Org.List{} = list <- Org.contents(section_or_document), do: list
  end

  @doc "Extracts all contents from given section or document"
  @spec contents(Org.Document.t() | Org.Section.t()) :: list(Org.Content.t())
  def contents(section_or_document)

  def contents(%Org.Document{} = doc) do
    Org.Document.contents(doc)
  end

  def contents(%Org.Section{} = section) do
    Org.Section.contents(section)
  end

  @doc ~S"""
  Extracts all sections with TODO keywords from the document or section.

  Example:
      iex> doc = Org.load_string("* TODO Task 1\n** DONE Subtask\n* Regular header\n* TODO Task 2")
      iex> todos = Org.todo_items(doc)
      iex> for section <- todos, do: {section.title, section.todo_keyword}
      [{"Task 1", "TODO"}, {"Subtask", "DONE"}, {"Task 2", "TODO"}]
  """
  @spec todo_items(Org.Document.t() | Org.Section.t()) :: list(Org.Section.t())
  def todo_items(doc_or_section)

  def todo_items(%Org.Document{sections: sections}) do
    Enum.flat_map(sections, &extract_todo_sections/1)
  end

  def todo_items(%Org.Section{} = section) do
    extract_todo_sections(section)
  end

  defp extract_todo_sections(%Org.Section{todo_keyword: nil, children: children}) do
    Enum.flat_map(children, &extract_todo_sections/1)
  end

  defp extract_todo_sections(%Org.Section{todo_keyword: _todo, children: children} = section) do
    [section | Enum.flat_map(children, &extract_todo_sections/1)]
  end

  @doc ~S"""
  Extracts all sections with the specified priority from the document or section.

  Example:
      iex> doc = Org.load_string("* TODO [#A] High Priority\n** DONE [#B] Medium Priority\n* [#A] Another High\n* Regular")
      iex> high_priority = Org.sections_by_priority(doc, "A")
      iex> for section <- high_priority, do: section.title
      ["High Priority", "Another High"]
  """
  @spec sections_by_priority(Org.Document.t() | Org.Section.t(), String.t()) :: list(Org.Section.t())
  def sections_by_priority(doc_or_section, priority)

  def sections_by_priority(%Org.Document{sections: sections}, priority) do
    Enum.flat_map(sections, &extract_sections_by_priority(&1, priority))
  end

  def sections_by_priority(%Org.Section{} = section, priority) do
    extract_sections_by_priority(section, priority)
  end

  defp extract_sections_by_priority(
         %Org.Section{priority: target_priority, children: children} = section,
         target_priority
       ) do
    [section | Enum.flat_map(children, &extract_sections_by_priority(&1, target_priority))]
  end

  defp extract_sections_by_priority(%Org.Section{children: children}, target_priority) do
    Enum.flat_map(children, &extract_sections_by_priority(&1, target_priority))
  end

  # ============================================================================
  # Enhanced Priority Functions
  # ============================================================================

  @doc """
  Extracts all sections with priority at least as high as the specified minimum priority.

  Uses Org.Priority for comparison. A > B > C > nil.

  ## Examples

      iex> doc = Org.load_string(\"\"\"
      ...> * TODO [#A] High task
      ...> * TODO [#B] Medium task  
      ...> * TODO [#C] Low task
      ...> * TODO Regular task
      ...> \"\"\")
      iex> important = Org.sections_with_min_priority(doc, "B")
      iex> for section <- important, do: {section.title, section.priority}
      [{"High task", "A"}, {"Medium task", "B"}]
  """
  @spec sections_with_min_priority(Org.Document.t() | Org.Section.t(), String.t() | nil) :: [Org.Section.t()]
  def sections_with_min_priority(doc_or_section, min_priority) do
    all_sections = extract_all_sections(doc_or_section)

    Enum.filter(all_sections, fn section ->
      section.priority != nil && Org.Priority.at_least?(section.priority, min_priority)
    end)
  end

  @doc """
  Extracts all sections with priority in the given range (inclusive).

  ## Examples

      iex> doc = Org.load_string(\"\"\"
      ...> * TODO [#A] High task
      ...> * TODO [#B] Medium task  
      ...> * TODO [#C] Low task
      ...> \"\"\")
      iex> mid_priority = Org.sections_with_priority_range(doc, "B", "C")
      iex> for section <- mid_priority, do: section.title
      ["Medium task", "Low task"]
  """
  @spec sections_with_priority_range(Org.Document.t() | Org.Section.t(), String.t(), String.t()) :: [Org.Section.t()]
  def sections_with_priority_range(doc_or_section, min_priority, max_priority) do
    all_sections = extract_all_sections(doc_or_section)

    Enum.filter(all_sections, fn section ->
      section.priority != nil && Org.Priority.in_range?(section.priority, min_priority, max_priority)
    end)
  end

  @doc """
  Sorts sections by priority in descending order (A → B → C → nil).

  ## Examples

      iex> doc = Org.load_string(\"\"\"
      ...> * TODO [#C] Low task
      ...> * TODO [#A] High task
      ...> * TODO [#B] Medium task
      ...> * TODO Regular task
      ...> \"\"\")
      iex> sorted = Org.sections_sorted_by_priority(doc)
      iex> for section <- sorted, do: {section.title, section.priority}
      [{"High task", "A"}, {"Medium task", "B"}, {"Low task", "C"}, {"Regular task", nil}]
  """
  @spec sections_sorted_by_priority(Org.Document.t() | Org.Section.t()) :: [Org.Section.t()]
  def sections_sorted_by_priority(doc_or_section) do
    all_sections = extract_all_sections(doc_or_section)

    Enum.sort(all_sections, fn section1, section2 ->
      Org.Priority.higher?(section1.priority, section2.priority)
    end)
  end

  @doc """
  Extracts all high-priority sections (priority A).

  ## Examples

      iex> doc = Org.load_string(\"\"\"
      ...> * TODO [#A] Critical task
      ...> * TODO [#B] Medium task
      ...> \"\"\")
      iex> high = Org.high_priority_sections(doc)
      iex> for section <- high, do: section.title
      ["Critical task"]
  """
  @spec high_priority_sections(Org.Document.t() | Org.Section.t()) :: [Org.Section.t()]
  def high_priority_sections(doc_or_section) do
    sections_by_priority(doc_or_section, "A")
  end

  @doc """
  Calculates the effective priority of a section considering inheritance.

  If a section has no priority, it inherits from its parent sections.
  Returns the first non-nil priority found in the parent chain.

  ## Examples

      iex> doc = Org.load_string(\"\"\"
      ...> * TODO [#A] Parent task
      ...> ** TODO Child task
      ...> *** TODO Grandchild task
      ...> \"\"\")
      iex> _child = Org.section(doc, ["Parent task", "Child task"])
      iex> Org.effective_priority(doc, ["Parent task", "Child task"])
      "A"
  """
  @spec effective_priority(Org.Document.t(), [String.t()]) :: String.t() | nil
  def effective_priority(doc, path) do
    case path do
      [] ->
        # Document level has no priority
        nil

      _ ->
        # Get the target section
        section = section(doc, path)

        # If section has its own priority, return it
        if section.priority do
          section.priority
        else
          # Walk up the parent chain to find inherited priority
          find_inherited_priority(doc, path)
        end
    end
  end

  @doc """
  Extracts all sections that have an effective priority (either direct or inherited).

  ## Examples

      iex> doc = Org.load_string(\"\"\"
      ...> * TODO [#A] Parent
      ...> ** TODO Child with no priority
      ...> * TODO [#B] Another parent  
      ...> ** TODO Another child
      ...> * TODO Regular task
      ...> \"\"\")
      iex> effective = Org.sections_with_effective_priority(doc)
      iex> length(effective)
      4
  """
  @spec sections_with_effective_priority(Org.Document.t() | Org.Section.t()) :: [Org.Section.t()]
  def sections_with_effective_priority(doc_or_section) do
    all_sections_with_paths = extract_all_sections_with_paths(doc_or_section)

    Enum.filter(all_sections_with_paths, fn {_section, path} ->
      effective_priority(doc_or_section, path) != nil
    end)
    |> Enum.map(fn {section, _path} -> section end)
  end

  # Helper functions for enhanced priority features

  defp extract_all_sections(%Org.Document{sections: sections}) do
    Enum.flat_map(sections, &extract_all_sections/1)
  end

  defp extract_all_sections(%Org.Section{} = section) do
    children = Enum.flat_map(section.children, &extract_all_sections/1)
    [section | children]
  end

  defp find_inherited_priority(_doc, [_last]) do
    # Top level, no parent
    nil
  end

  defp find_inherited_priority(doc, path) do
    parent_path = Enum.drop(path, -1)
    parent_section = section(doc, parent_path)

    if parent_section.priority do
      parent_section.priority
    else
      find_inherited_priority(doc, parent_path)
    end
  end

  defp extract_all_sections_with_paths(%Org.Document{sections: sections}) do
    Enum.flat_map(sections, &extract_sections_with_paths(&1, []))
  end

  defp extract_all_sections_with_paths(%Org.Section{} = section) do
    extract_sections_with_paths(section, [])
  end

  defp extract_sections_with_paths(%Org.Section{title: title, children: children} = section, parent_path) do
    current_path = parent_path ++ [title]
    child_sections = Enum.flat_map(children, &extract_sections_with_paths(&1, current_path))
    [{section, current_path} | child_sections]
  end

  @doc """
  Converts an Org document or any Org struct to a JSON-encodable map.

  This function transforms Org structures into plain Elixir maps that can be
  easily serialized to JSON using any JSON library.

  ## Examples

      iex> doc = Org.load_string("* TODO Task\\nDescription")
      iex> json_map = Org.to_json_map(doc)
      iex> json_map.type
      "document"
      iex> List.first(json_map.sections).todo_keyword
      "TODO"

      iex> para = %Org.Paragraph{lines: ["Hello *world*"]}
      iex> Org.to_json_map(para)
      %{type: "paragraph", lines: ["Hello *world*"]}
  """
  @spec to_json_map(any()) :: map()
  def to_json_map(org_struct) do
    Org.JSONEncodable.to_json_map(org_struct)
  end

  @doc """
  Encodes an Org document or any Org struct to a JSON-encodable map.

  Alias for `to_json_map/1` using the encoder module directly.

  ## Examples

      iex> doc = Org.load_string("#+COMMENT: Test comment\\n* Section")
      iex> encoded = Org.encode_json(doc)
      iex> encoded.type
      "document"
      iex> encoded.comments
      ["+COMMENT: Test comment"]
  """
  @spec encode_json(any()) :: map()
  def encode_json(org_struct) do
    Org.JSONEncoder.encode(org_struct)
  end

  # Write mode functions

  @doc """
  Adds a new section to the document at the specified path.

  ## Examples

      iex> doc = Org.load_string("* Parent")
      iex> doc = Org.add_section(doc, ["Parent"], "Child", "TODO", "A")
      iex> Org.NodeFinder.find_by_path(doc, ["Parent", "Child"]).title
      "Child"
  """
  @spec add_section(Org.Document.t(), list(String.t()), String.t(), String.t() | nil, String.t() | nil) ::
          Org.Document.t()
  def add_section(doc, path, title, todo_keyword \\ nil, priority \\ nil) do
    Org.Writer.add_section(doc, path, title, todo_keyword, priority)
  end

  @doc """
  Adds content to the document at the specified path.

  ## Examples

      iex> doc = Org.load_string("* Section")
      iex> para = %Org.Paragraph{lines: ["New content"]}
      iex> doc = Org.add_content(doc, ["Section"], para)
      iex> contents = Org.section(doc, ["Section"]).contents
      iex> length(contents)
      1
  """
  @spec add_content(Org.Document.t(), list(String.t()), Org.Content.t()) :: Org.Document.t()
  def add_content(doc, path, content) do
    Org.Writer.add_content(doc, path, content)
  end

  @doc """
  Updates a node at the specified path using the given function.

  ## Examples

      iex> doc = Org.load_string("* Section")
      iex> doc = Org.update_node(doc, ["Section"], fn s -> %{s | todo_keyword: "TODO"} end)
      iex> Org.section(doc, ["Section"]).todo_keyword
      "TODO"
  """
  @spec update_node(Org.Document.t(), list(String.t()), function()) :: Org.Document.t()
  def update_node(doc, path, updater) do
    Org.Writer.update_node(doc, path, updater)
  end

  @doc """
  Removes a node at the specified path.

  ## Examples

      iex> doc = Org.load_string("* A\\n* B\\n* C")
      iex> doc = Org.remove_node(doc, ["B"])
      iex> titles = Enum.map(doc.sections, & &1.title)
      iex> titles
      ["A", "C"]
  """
  @spec remove_node(Org.Document.t(), list(String.t())) :: Org.Document.t()
  def remove_node(doc, path) do
    Org.Writer.remove_node(doc, path)
  end

  @doc """
  Moves a node from one path to another.

  ## Examples

      iex> doc = Org.load_string("* A\\n** Child\\n* B")
      iex> doc = Org.move_node(doc, ["A", "Child"], ["B"])
      iex> Org.NodeFinder.find_by_path(doc, ["B", "Child"]) != nil
      true
  """
  @spec move_node(Org.Document.t(), list(String.t()), list(String.t())) :: Org.Document.t()
  def move_node(doc, from_path, to_path) do
    Org.Writer.move_node(doc, from_path, to_path)
  end

  @doc """
  Finds a node at the specified path in the document.

  ## Examples

      iex> doc = Org.load_string("* Parent\\n** Child")
      iex> node = Org.find_node(doc, ["Parent", "Child"])
      iex> node.title
      "Child"
  """
  @spec find_node(Org.Document.t(), list(String.t())) :: any()
  def find_node(doc, path) do
    Org.NodeFinder.find_by_path(doc, path)
  end

  @doc """
  Converts an Org document back to org-mode text format.

  ## Examples

      iex> doc = Org.load_string("* Section\\nContent")
      iex> org_text = Org.to_org_string(doc)
      iex> org_text =~ "* Section"
      true
  """
  @spec to_org_string(Org.Document.t()) :: String.t()
  def to_org_string(doc) do
    Org.Writer.to_org_string(doc)
  end

  # Fragment parsing functions

  @doc """
  Parses a fragment of org-mode text with position tracking.

  Useful for incremental editing where you need to parse partial content
  while preserving styling and position information.

  ## Options

  - `:type` - Expected fragment type (auto-detected if not provided)
  - `:start_position` - Starting position in the original document
  - `:context` - Parent context for proper parsing
  - `:preserve_whitespace` - Keep original whitespace (default: true)

  ## Examples

      iex> fragment = Org.parse_fragment("** TODO [#A] Important task")
      iex> fragment.content.title
      "Important task"

      iex> fragment = Org.parse_fragment("This is *bold* text.", type: :text)
      iex> fragment.type
      :text
  """
  @spec parse_fragment(String.t(), keyword()) :: Org.FragmentParser.fragment()
  def parse_fragment(text, opts \\ []) do
    Org.FragmentParser.parse_fragment(text, opts)
  end

  @doc """
  Parses multiple fragments from text, typically separated by newlines.

  ## Examples

      iex> fragments = Org.parse_fragments("* Section 1\\n\\nSome content\\n\\n* Section 2")
      iex> length(fragments)
      3
  """
  @spec parse_fragments(String.t(), keyword()) :: [Org.FragmentParser.fragment()]
  def parse_fragments(text, opts \\ []) do
    Org.FragmentParser.parse_fragments(text, opts)
  end

  @doc """
  Updates an existing fragment with new content while preserving position info.

  ## Examples

      iex> fragment = Org.parse_fragment("* Old title")
      iex> updated = Org.update_fragment(fragment, "* New title")
      iex> updated.content.title
      "New title"
  """
  @spec update_fragment(Org.FragmentParser.fragment(), String.t()) :: Org.FragmentParser.fragment()
  def update_fragment(fragment, new_text) do
    Org.FragmentParser.update_fragment(fragment, new_text)
  end

  @doc """
  Renders a fragment back to org-mode text format.

  ## Examples

      iex> fragment = Org.parse_fragment("** TODO Task")
      iex> Org.render_fragment(fragment)
      "** TODO Task"
  """
  @spec render_fragment(Org.FragmentParser.fragment()) :: String.t()
  def render_fragment(fragment) do
    Org.FragmentParser.render_fragment(fragment)
  end

  # Incremental parsing functions

  @doc """
  Creates a new incremental parse state for efficient document editing.

  The incremental parser allows you to make changes to specific parts of
  a document without re-parsing the entire text, which is much more efficient
  for large documents or frequent edits.

  ## Examples

      iex> state = Org.new_incremental_parser("* Section 1\\n\\nContent\\n\\n* Section 2")
      iex> state.document != nil
      true
  """
  @spec new_incremental_parser(String.t()) :: Org.IncrementalParser.parse_state()
  def new_incremental_parser(source_text) do
    Org.IncrementalParser.new(source_text)
  end

  @doc """
  Applies a text change to the incremental parse state.

  Changes are queued and processed when `commit_incremental_changes/1` is called.

  ## Examples

      iex> state = Org.new_incremental_parser("* Old Title")
      iex> change = %{
      ...>   range: {{1, 3}, {1, 12}},
      ...>   old_text: "Old Title",
      ...>   new_text: "New Title"
      ...> }
      iex> updated_state = Org.apply_incremental_change(state, change)
      iex> Org.has_pending_incremental_changes?(updated_state)
      true
  """
  @spec apply_incremental_change(Org.IncrementalParser.parse_state(), Org.IncrementalParser.text_change()) ::
          Org.IncrementalParser.parse_state()
  def apply_incremental_change(state, change) do
    Org.IncrementalParser.apply_change(state, change)
  end

  @doc """
  Commits all pending incremental changes and re-parses affected document parts.

  ## Examples

      iex> state = Org.new_incremental_parser("* Section")
      iex> change = %{range: {{1, 1}, {1, 9}}, old_text: "* Section", new_text: "* Updated"}
      iex> state = Org.apply_incremental_change(state, change)
      iex> committed_state = Org.commit_incremental_changes(state)
      iex> committed_state.version > state.version
      true
  """
  @spec commit_incremental_changes(Org.IncrementalParser.parse_state()) :: Org.IncrementalParser.parse_state()
  def commit_incremental_changes(state) do
    Org.IncrementalParser.commit_changes(state)
  end

  @doc """
  Checks if there are pending incremental changes that haven't been committed.

  ## Examples

      iex> state = Org.new_incremental_parser("* Section")
      iex> Org.has_pending_incremental_changes?(state)
      false
  """
  @spec has_pending_incremental_changes?(Org.IncrementalParser.parse_state()) :: boolean()
  def has_pending_incremental_changes?(state) do
    Org.IncrementalParser.has_pending_changes?(state)
  end

  # ============================================================================
  # Planning and Scheduling Functions
  # ============================================================================

  @doc """
  Adds a SCHEDULED timestamp to a section.

  ## Examples

      iex> doc = Org.load_string("* TODO Task")
      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon 09:00>")
      iex> doc = Org.schedule(doc, ["Task"], timestamp)
      iex> task = Org.section(doc, ["Task"])
      iex> task.metadata.scheduled.date
      ~D[2024-01-15]
  """
  @spec schedule(Org.Document.t(), [String.t()], Org.Timestamp.t()) :: Org.Document.t()
  def schedule(doc, path, timestamp) do
    Org.Writer.schedule(doc, path, timestamp)
  end

  @doc """
  Adds a DEADLINE timestamp to a section.

  ## Examples

      iex> doc = Org.load_string("* TODO Task")
      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-20 Sat>")
      iex> doc = Org.deadline(doc, ["Task"], timestamp)
      iex> task = Org.section(doc, ["Task"])
      iex> task.metadata.deadline.date
      ~D[2024-01-20]
  """
  @spec deadline(Org.Document.t(), [String.t()], Org.Timestamp.t()) :: Org.Document.t()
  def deadline(doc, path, timestamp) do
    Org.Writer.deadline(doc, path, timestamp)
  end

  @doc """
  Marks a task as completed with a CLOSED timestamp.

  ## Examples

      iex> doc = Org.load_string("* TODO Task")
      iex> doc = Org.complete_task(doc, ["Task"])
      iex> task = Org.section(doc, ["Task"])
      iex> task.todo_keyword
      "DONE"
      iex> task.metadata.closed != nil
      true
  """
  @spec complete_task(Org.Document.t(), [String.t()], DateTime.t() | nil) :: Org.Document.t()
  def complete_task(doc, path, completion_time \\ nil) do
    Org.Writer.complete_task(doc, path, completion_time)
  end

  @doc """
  Creates a new section with scheduling information.

  ## Examples

      iex> doc = Org.load_string("* Parent")
      iex> {:ok, scheduled} = Org.Timestamp.parse("<2024-01-15 Mon 09:00>")
      iex> doc = Org.add_scheduled_task(doc, ["Parent"], "Important Task", "TODO", "A", scheduled)
      iex> task = Org.section(doc, ["Parent", "Important Task"])
      iex> task.metadata.scheduled.date
      ~D[2024-01-15]
  """
  @spec add_scheduled_task(
          Org.Document.t(),
          [String.t()],
          String.t(),
          String.t() | nil,
          String.t() | nil,
          Org.Timestamp.t() | nil,
          Org.Timestamp.t() | nil
        ) :: Org.Document.t()
  def add_scheduled_task(doc, path, title, todo_keyword \\ "TODO", priority \\ nil, scheduled \\ nil, deadline \\ nil) do
    Org.Writer.add_scheduled_section(doc, path, title, todo_keyword, priority, scheduled, deadline)
  end

  @doc """
  Removes scheduling information from a section.

  ## Examples

      iex> doc = Org.load_string("* Task\\n  SCHEDULED: <2024-01-15 Mon>")
      iex> doc = Org.unschedule(doc, ["Task"])
      iex> task = Org.section(doc, ["Task"])
      iex> Map.get(task.metadata, :scheduled)
      nil
  """
  @spec unschedule(Org.Document.t(), [String.t()]) :: Org.Document.t()
  def unschedule(doc, path) do
    Org.Writer.unschedule(doc, path)
  end

  @doc """
  Extracts all sections that are scheduled.

  ## Examples

      iex> doc = Org.load_string("* TODO Task 1\\nSCHEDULED: <2024-01-15 Mon>\\n* Task 2\\n* TODO Task 3\\nSCHEDULED: <2024-01-20 Sat>")
      iex> scheduled = Org.scheduled_items(doc)
      iex> length(scheduled)
      2
  """
  @spec scheduled_items(Org.Document.t() | Org.Section.t()) :: [Org.Section.t()]
  def scheduled_items(doc_or_section) do
    extract_sections_with_metadata(doc_or_section, :scheduled)
  end

  @doc """
  Extracts all sections that have deadlines.

  ## Examples

      iex> doc = Org.load_string("* TODO Task 1\\nDEADLINE: <2024-01-15 Mon>\\n* Task 2\\n* TODO Task 3\\nDEADLINE: <2024-01-20 Sat>")
      iex> deadlines = Org.deadline_items(doc)
      iex> length(deadlines)
      2
  """
  @spec deadline_items(Org.Document.t() | Org.Section.t()) :: [Org.Section.t()]
  def deadline_items(doc_or_section) do
    extract_sections_with_metadata(doc_or_section, :deadline)
  end

  @doc """
  Extracts all sections that are closed/completed.

  ## Examples

      iex> doc = Org.load_string("* DONE Task 1\\nCLOSED: [2024-01-15 Mon]\\n* TODO Task 2\\n* DONE Task 3\\nCLOSED: [2024-01-20 Sat]")
      iex> completed = Org.closed_items(doc)
      iex> length(completed)
      2
  """
  @spec closed_items(Org.Document.t() | Org.Section.t()) :: [Org.Section.t()]
  def closed_items(doc_or_section) do
    extract_sections_with_metadata(doc_or_section, :closed)
  end

  @doc """
  Extracts sections scheduled for today.

  ## Examples

      iex> doc = Org.load_string("* TODO Task\\n  SCHEDULED: <2024-01-15 Mon>")
      iex> today_tasks = Org.agenda_items(doc, ~D[2024-01-15])
      iex> length(today_tasks)
      1
  """
  @spec agenda_items(Org.Document.t() | Org.Section.t(), Date.t()) :: [Org.Section.t()]
  def agenda_items(doc_or_section, date \\ Date.utc_today()) do
    doc_or_section
    |> scheduled_items()
    |> Enum.filter(fn section ->
      case section.metadata[:scheduled] do
        %Org.Timestamp{date: scheduled_date} -> Date.compare(scheduled_date, date) == :eq
        _ -> false
      end
    end)
  end

  @doc """
  Extracts overdue tasks (past deadline and not completed).

  ## Examples

      iex> doc = Org.load_string("* TODO Task\\n  DEADLINE: <2024-01-10 Wed>")
      iex> overdue = Org.overdue_items(doc, ~D[2024-01-15])
      iex> length(overdue)
      1
  """
  @spec overdue_items(Org.Document.t() | Org.Section.t(), Date.t()) :: [Org.Section.t()]
  def overdue_items(doc_or_section, today \\ Date.utc_today()) do
    doc_or_section
    |> deadline_items()
    |> Enum.filter(fn section ->
      section.todo_keyword != "DONE" &&
        case section.metadata[:deadline] do
          %Org.Timestamp{date: deadline_date} -> Date.compare(deadline_date, today) == :lt
          _ -> false
        end
    end)
  end

  # Helper function to extract sections with specific metadata
  defp extract_sections_with_metadata(%Org.Document{sections: sections}, metadata_key) do
    Enum.flat_map(sections, &extract_sections_with_metadata(&1, metadata_key))
  end

  defp extract_sections_with_metadata(%Org.Section{} = section, metadata_key) do
    current = if section.metadata[metadata_key], do: [section], else: []
    children = Enum.flat_map(section.children, &extract_sections_with_metadata(&1, metadata_key))
    current ++ children
  end

  # ============================================================================
  # Workflow Configuration and Management Functions
  # ============================================================================

  @doc """
  Creates a TODO workflow sequence configuration.

  ## Examples

      iex> workflow = Org.create_todo_sequence(["TODO", "DOING"], ["DONE"])
      iex> workflow.active
      ["TODO", "DOING"]
      iex> workflow.done
      ["DONE"]
  """
  @spec create_todo_sequence([String.t()], [String.t()]) :: Org.Writer.todo_sequence()
  def create_todo_sequence(active_states, done_states) do
    Org.Writer.create_todo_sequence(active_states, done_states)
  end

  @doc """
  Creates a comprehensive workflow configuration with multiple sequences.

  ## Examples

      iex> basic = Org.create_todo_sequence(["TODO"], ["DONE"])
      iex> dev = Org.create_todo_sequence(["TODO", "INPROGRESS", "REVIEW"], ["DONE", "CANCELLED"])
      iex> config = Org.create_workflow_config([basic, dev])
      iex> length(config.sequences)
      2
  """
  @spec create_workflow_config([Org.Writer.todo_sequence()], Org.Writer.todo_sequence() | nil) ::
          Org.Writer.workflow_config()
  def create_workflow_config(sequences, default_sequence \\ nil) do
    default_sequence = default_sequence || List.first(sequences) || Org.Writer.create_todo_sequence(["TODO"], ["DONE"])
    Org.Writer.create_workflow_config(sequences, default_sequence)
  end

  @doc """
  Gets the default workflow configuration (TODO -> DONE).

  ## Examples

      iex> config = Org.default_workflow_config()
      iex> config.default_sequence.active
      ["TODO"]
      iex> config.default_sequence.done
      ["DONE"]
  """
  @spec default_workflow_config() :: Org.Writer.workflow_config()
  def default_workflow_config do
    Org.Writer.default_workflow_config()
  end

  @doc """
  Cycles a TODO keyword to the next state in its workflow sequence.

  ## Examples

      iex> doc = Org.load_string("* TODO Task")
      iex> doc = Org.cycle_todo(doc, ["Task"])
      iex> task = Org.section(doc, ["Task"])
      iex> task.todo_keyword
      "DONE"

      iex> doc = Org.load_string("* DONE Task")
      iex> doc = Org.cycle_todo(doc, ["Task"])
      iex> task = Org.section(doc, ["Task"])
      iex> task.todo_keyword
      nil
  """
  @spec cycle_todo(Org.Document.t(), [String.t()], Org.Writer.workflow_config() | nil) :: Org.Document.t()
  def cycle_todo(doc, path, workflow_config \\ nil) do
    Org.Writer.cycle_todo(doc, path, workflow_config)
  end

  @doc """
  Cycles a TODO keyword backwards to the previous state in its workflow sequence.

  ## Examples

      iex> doc = Org.load_string("* DONE Task")
      iex> doc = Org.cycle_todo_backward(doc, ["Task"])
      iex> task = Org.section(doc, ["Task"])
      iex> task.todo_keyword
      "TODO"
  """
  @spec cycle_todo_backward(Org.Document.t(), [String.t()], Org.Writer.workflow_config() | nil) :: Org.Document.t()
  def cycle_todo_backward(doc, path, workflow_config \\ nil) do
    Org.Writer.cycle_todo_backward(doc, path, workflow_config)
  end

  @doc """
  Sets a specific TODO keyword on a section.

  ## Examples

      iex> doc = Org.load_string("* Task")
      iex> doc = Org.set_todo_keyword(doc, ["Task"], "TODO")
      iex> task = Org.section(doc, ["Task"])
      iex> task.todo_keyword
      "TODO"
  """
  @spec set_todo_keyword(Org.Document.t(), [String.t()], String.t() | nil) :: Org.Document.t()
  def set_todo_keyword(doc, path, keyword) do
    Org.Writer.set_todo_keyword(doc, path, keyword)
  end

  @doc """
  Removes TODO keyword from a section (sets it to nil).

  ## Examples

      iex> doc = Org.load_string("* TODO Task")
      iex> doc = Org.clear_todo_keyword(doc, ["Task"])
      iex> task = Org.section(doc, ["Task"])
      iex> task.todo_keyword
      nil
  """
  @spec clear_todo_keyword(Org.Document.t(), [String.t()]) :: Org.Document.t()
  def clear_todo_keyword(doc, path) do
    Org.Writer.clear_todo_keyword(doc, path)
  end

  @doc """
  Checks if a keyword represents a "done" state in any workflow sequence.

  ## Examples

      iex> config = Org.default_workflow_config()
      iex> Org.todo_keyword_done?("DONE", config)
      true
      iex> Org.todo_keyword_done?("TODO", config)
      false
  """
  @spec todo_keyword_done?(String.t() | nil, Org.Writer.workflow_config()) :: boolean()
  def todo_keyword_done?(keyword, workflow_config) do
    Org.Writer.todo_keyword_done?(keyword, workflow_config)
  end

  @doc """
  Checks if a keyword represents an "active" state in any workflow sequence.

  ## Examples

      iex> config = Org.default_workflow_config()
      iex> Org.todo_keyword_active?("TODO", config)
      true
      iex> Org.todo_keyword_active?("DONE", config)
      false
  """
  @spec todo_keyword_active?(String.t() | nil, Org.Writer.workflow_config()) :: boolean()
  def todo_keyword_active?(keyword, workflow_config) do
    Org.Writer.todo_keyword_active?(keyword, workflow_config)
  end

  @doc """
  Gets all possible TODO keywords from a workflow configuration.

  ## Examples

      iex> config = Org.default_workflow_config()
      iex> keywords = Org.all_todo_keywords(config)
      iex> "TODO" in keywords
      true
      iex> "DONE" in keywords
      true
  """
  @spec all_todo_keywords(Org.Writer.workflow_config()) :: [String.t()]
  def all_todo_keywords(workflow_config) do
    Org.Writer.all_todo_keywords(workflow_config)
  end

  @doc """
  Extracts all sections with specific TODO keywords.

  ## Examples

      iex> doc = Org.load_string("* TODO Task 1\\n* DONE Task 2\\n* TODO Task 3")
      iex> todos = Org.sections_by_todo_keyword(doc, "TODO")
      iex> length(todos)
      2
      iex> for section <- todos, do: section.title
      ["Task 1", "Task 3"]
  """
  @spec sections_by_todo_keyword(Org.Document.t() | Org.Section.t(), String.t()) :: [Org.Section.t()]
  def sections_by_todo_keyword(doc_or_section, keyword) do
    extract_sections_by_todo_keyword(doc_or_section, keyword)
  end

  @doc """
  Extracts all sections that have any TODO keyword (active or done).

  ## Examples

      iex> doc = Org.load_string("* TODO Task 1\\n* Regular Section\\n* DONE Task 2")
      iex> todos = Org.all_todo_sections(doc)
      iex> length(todos)
      2
      iex> for section <- todos, do: {section.title, section.todo_keyword}
      [{"Task 1", "TODO"}, {"Task 2", "DONE"}]
  """
  @spec all_todo_sections(Org.Document.t() | Org.Section.t()) :: [Org.Section.t()]
  def all_todo_sections(doc_or_section) do
    extract_all_todo_sections(doc_or_section)
  end

  @doc """
  Extracts all sections with "active" TODO keywords (not done states).

  ## Examples

      iex> config = Org.default_workflow_config()
      iex> doc = Org.load_string("* TODO Task 1\\n* DONE Task 2\\n* TODO Task 3")
      iex> active_todos = Org.active_todo_sections(doc, config)
      iex> length(active_todos)
      2
  """
  @spec active_todo_sections(Org.Document.t() | Org.Section.t(), Org.Writer.workflow_config()) :: [Org.Section.t()]
  def active_todo_sections(doc_or_section, workflow_config) do
    doc_or_section
    |> all_todo_sections()
    |> Enum.filter(fn section ->
      Org.Writer.todo_keyword_active?(section.todo_keyword, workflow_config)
    end)
  end

  @doc """
  Extracts all sections with "done" TODO keywords.

  ## Examples

      iex> config = Org.default_workflow_config()
      iex> doc = Org.load_string("* TODO Task 1\\n* DONE Task 2\\n* DONE Task 3")
      iex> done_todos = Org.done_todo_sections(doc, config)
      iex> length(done_todos)
      2
  """
  @spec done_todo_sections(Org.Document.t() | Org.Section.t(), Org.Writer.workflow_config()) :: [Org.Section.t()]
  def done_todo_sections(doc_or_section, workflow_config) do
    doc_or_section
    |> all_todo_sections()
    |> Enum.filter(fn section ->
      Org.Writer.todo_keyword_done?(section.todo_keyword, workflow_config)
    end)
  end

  # Helper functions for TODO keyword extraction
  defp extract_sections_by_todo_keyword(%Org.Document{sections: sections}, keyword) do
    Enum.flat_map(sections, &extract_sections_by_todo_keyword(&1, keyword))
  end

  defp extract_sections_by_todo_keyword(%Org.Section{} = section, keyword) do
    current = if section.todo_keyword == keyword, do: [section], else: []
    children = Enum.flat_map(section.children, &extract_sections_by_todo_keyword(&1, keyword))
    current ++ children
  end

  defp extract_all_todo_sections(%Org.Document{sections: sections}) do
    Enum.flat_map(sections, &extract_all_todo_sections/1)
  end

  defp extract_all_todo_sections(%Org.Section{} = section) do
    current = if section.todo_keyword, do: [section], else: []
    children = Enum.flat_map(section.children, &extract_all_todo_sections/1)
    current ++ children
  end

  # ============================================================================
  # Repeater Interval Functions
  # ============================================================================

  @doc """
  Completes a repeating task by advancing its timestamps to the next occurrence
  and resetting its TODO state.

  ## Examples

      iex> doc = Org.load_string("* TODO Weekly Meeting\\n  SCHEDULED: <2024-01-15 Mon 09:00 +1w>")
      iex> doc = Org.complete_repeating_task(doc, ["Weekly Meeting"])
      iex> task = Org.section(doc, ["Weekly Meeting"])
      iex> task.todo_keyword
      "TODO"
      iex> task.metadata.scheduled.date
      ~D[2024-01-22]
  """
  @spec complete_repeating_task(Org.Document.t(), [String.t()], DateTime.t() | nil) :: Org.Document.t()
  def complete_repeating_task(doc, path, completion_time \\ nil) do
    Org.Writer.complete_repeating_task(doc, path, completion_time)
  end

  @doc """
  Advances all repeating timestamps in a section to their next occurrences.

  ## Examples

      iex> doc = Org.load_string("* Task\\n  SCHEDULED: <2024-01-15 Mon +1w>")
      iex> doc = Org.advance_repeaters(doc, ["Task"])
      iex> task = Org.section(doc, ["Task"])
      iex> task.metadata.scheduled.date
      ~D[2024-01-22]
  """
  @spec advance_repeaters(Org.Document.t(), [String.t()]) :: Org.Document.t()
  def advance_repeaters(doc, path) do
    Org.Writer.advance_repeaters(doc, path)
  end

  @doc """
  Checks if a section has any repeating timestamps.

  ## Examples

      iex> doc = Org.load_string("* Task\\n  SCHEDULED: <2024-01-15 Mon +1w>")
      iex> task = Org.section(doc, ["Task"])
      iex> Org.has_repeating_timestamps?(task.metadata)
      true
  """
  @spec has_repeating_timestamps?(map()) :: boolean()
  def has_repeating_timestamps?(metadata) do
    Org.Writer.has_repeating_timestamps?(metadata)
  end

  @doc """
  Sets a repeating scheduled timestamp for a section.

  ## Examples

      iex> doc = Org.load_string("* Task")
      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon 09:00 +1w>")
      iex> doc = Org.schedule_repeating(doc, ["Task"], timestamp)
      iex> task = Org.section(doc, ["Task"])
      iex> Org.Timestamp.repeating?(task.metadata.scheduled)
      true
  """
  @spec schedule_repeating(Org.Document.t(), [String.t()], Org.Timestamp.t()) :: Org.Document.t()
  def schedule_repeating(doc, path, timestamp) do
    Org.Writer.schedule_repeating(doc, path, timestamp)
  end

  @doc """
  Sets a repeating deadline timestamp for a section.
  """
  @spec deadline_repeating(Org.Document.t(), [String.t()], Org.Timestamp.t()) :: Org.Document.t()
  def deadline_repeating(doc, path, timestamp) do
    Org.Writer.deadline_repeating(doc, path, timestamp)
  end

  @doc """
  Extracts all sections that have repeating timestamps.

  ## Examples

      iex> doc = Org.load_string("* TODO Daily Standup\\n  SCHEDULED: <2024-01-15 Mon 09:00 +1d>\\n* TODO One-time Task\\n  SCHEDULED: <2024-01-16 Tue>")
      iex> repeating_tasks = Org.repeating_sections(doc)
      iex> length(repeating_tasks)
      1
      iex> hd(repeating_tasks).title
      "Daily Standup"
  """
  @spec repeating_sections(Org.Document.t() | Org.Section.t()) :: [Org.Section.t()]
  def repeating_sections(doc_or_section) do
    doc_or_section
    |> all_todo_sections()
    |> Enum.filter(fn section ->
      has_repeating_timestamps?(section.metadata)
    end)
  end

  @doc """
  Finds all sections scheduled for today, including repeating occurrences.

  ## Examples

      iex> doc = Org.load_string("* TODO Daily Meeting\\n  SCHEDULED: <2024-01-10 Wed 09:00 +1d>")
      iex> today_items = Org.agenda_items_with_repeaters(doc, ~D[2024-01-15])
      iex> length(today_items)
      1
  """
  @spec agenda_items_with_repeaters(Org.Document.t() | Org.Section.t(), Date.t()) :: [Org.Section.t()]
  def agenda_items_with_repeaters(doc_or_section, date \\ Date.utc_today()) do
    scheduled_sections = scheduled_items(doc_or_section)

    Enum.filter(scheduled_sections, fn section ->
      case section.metadata[:scheduled] do
        %Org.Timestamp{repeater: nil, date: scheduled_date} ->
          # Non-repeating: exact date match
          Date.compare(scheduled_date, date) == :eq

        %Org.Timestamp{repeater: %{}} = timestamp ->
          # Repeating: check if it occurs on this date
          occurrences = Org.Timestamp.occurrences_in_range(timestamp, date, date)
          length(occurrences) > 0

        _ ->
          false
      end
    end)
  end

  @doc """
  Finds overdue tasks, accounting for repeating deadlines.

  ## Examples

      iex> doc = Org.load_string("* TODO Weekly Report\\n  DEADLINE: <2024-01-10 Wed +1w>")
      iex> overdue = Org.overdue_items_with_repeaters(doc, ~D[2024-01-15])
      iex> length(overdue)
      0
  """
  @spec overdue_items_with_repeaters(Org.Document.t() | Org.Section.t(), Date.t()) :: [Org.Section.t()]
  def overdue_items_with_repeaters(doc_or_section, today \\ Date.utc_today()) do
    deadline_sections = deadline_items(doc_or_section)

    Enum.filter(deadline_sections, fn section ->
      section.todo_keyword != "DONE" && section_is_overdue?(section, today)
    end)
  end

  defp section_is_overdue?(section, today) do
    case section.metadata[:deadline] do
      %Org.Timestamp{repeater: nil, date: deadline_date} ->
        # Non-repeating: past deadline
        Date.compare(deadline_date, today) == :lt

      %Org.Timestamp{repeater: %{}} = timestamp ->
        # Repeating: check if the next occurrence is in the past
        check_repeating_deadline_overdue(timestamp, today)

      _ ->
        false
    end
  end

  defp check_repeating_deadline_overdue(timestamp, today) do
    case Org.Timestamp.next_occurrence_from(timestamp, Date.add(today, -1)) do
      %Org.Timestamp{date: next_date} ->
        Date.compare(next_date, today) == :lt

      _ ->
        false
    end
  end

  @doc """
  Finds all occurrences of repeating tasks within a date range.

  ## Examples

      iex> doc = Org.load_string("* TODO Daily Standup\\n  SCHEDULED: <2024-01-15 Mon 09:00 +1d>")
      iex> occurrences = Org.repeater_occurrences_in_range(doc, ~D[2024-01-15], ~D[2024-01-20])
      iex> length(occurrences)
      6
  """
  @spec repeater_occurrences_in_range(Org.Document.t() | Org.Section.t(), Date.t(), Date.t()) :: [
          {Org.Section.t(), Org.Timestamp.t()}
        ]
  def repeater_occurrences_in_range(doc_or_section, start_date, end_date) do
    repeating_sections(doc_or_section)
    |> Enum.flat_map(&section_occurrence_pairs(&1, start_date, end_date))
  end

  defp section_occurrence_pairs(section, start_date, end_date) do
    # Find all repeating timestamps in this section
    repeating_timestamps = get_repeating_timestamps(section)

    Enum.flat_map(repeating_timestamps, &timestamp_occurrences_for_section(&1, section, start_date, end_date))
  end

  defp timestamp_occurrences_for_section({_key, timestamp}, section, start_date, end_date) do
    occurrences = Org.Timestamp.occurrences_in_range(timestamp, start_date, end_date)
    Enum.map(occurrences, &{section, &1})
  end

  # ============================================================================
  # Property Drawer Management Functions
  # ============================================================================

  @doc """
  Adds a single property to a section's property drawer.

  Creates the property drawer if it doesn't exist, or adds to existing properties.

  ## Examples

      iex> doc = Org.load_string("* Task")
      iex> doc = Org.add_property(doc, ["Task"], "ID", "12345")
      iex> task = Org.section(doc, ["Task"])
      iex> task.properties["ID"]
      "12345"
  """
  @spec add_property(Org.Document.t(), [String.t()], String.t(), String.t()) :: Org.Document.t()
  def add_property(doc, path, key, value) do
    Org.Writer.update_node(doc, path, fn
      %Org.Section{} = section ->
        current_properties = section.properties || %{}
        %{section | properties: Map.put(current_properties, key, value)}

      _ ->
        raise ArgumentError, "Can only add properties to sections"
    end)
  end

  @doc """
  Sets multiple properties on a section, replacing existing properties.

  ## Examples

      iex> doc = Org.load_string("* Task")
      iex> properties = %{"ID" => "12345", "CATEGORY" => "work"}
      iex> doc = Org.set_properties(doc, ["Task"], properties)
      iex> task = Org.section(doc, ["Task"])
      iex> task.properties["ID"]
      "12345"
      iex> task.properties["CATEGORY"]
      "work"
  """
  @spec set_properties(Org.Document.t(), [String.t()], %{String.t() => String.t()}) :: Org.Document.t()
  def set_properties(doc, path, properties) when is_map(properties) do
    Org.Writer.update_node(doc, path, fn
      %Org.Section{} = section ->
        %{section | properties: properties}

      _ ->
        raise ArgumentError, "Can only set properties on sections"
    end)
  end

  @doc """
  Updates properties on a section by merging with existing properties.

  ## Examples

      iex> doc = Org.load_string("* Task")
      iex> doc = Org.add_property(doc, ["Task"], "ID", "12345")
      iex> doc = Org.update_properties(doc, ["Task"], %{"CATEGORY" => "work", "EFFORT" => "2h"})
      iex> task = Org.section(doc, ["Task"])
      iex> task.properties["ID"]
      "12345"
      iex> task.properties["CATEGORY"]
      "work"
  """
  @spec update_properties(Org.Document.t(), [String.t()], %{String.t() => String.t()}) :: Org.Document.t()
  def update_properties(doc, path, new_properties) when is_map(new_properties) do
    Org.Writer.update_node(doc, path, fn
      %Org.Section{} = section ->
        current_properties = section.properties || %{}
        %{section | properties: Map.merge(current_properties, new_properties)}

      _ ->
        raise ArgumentError, "Can only update properties on sections"
    end)
  end

  @doc """
  Removes a property from a section's property drawer.

  ## Examples

      iex> doc = Org.load_string("* Task")
      iex> doc = Org.add_property(doc, ["Task"], "ID", "12345")
      iex> doc = Org.remove_property(doc, ["Task"], "ID")
      iex> task = Org.section(doc, ["Task"])
      iex> task.properties["ID"]
      nil
  """
  @spec remove_property(Org.Document.t(), [String.t()], String.t()) :: Org.Document.t()
  def remove_property(doc, path, key) do
    Org.Writer.update_node(doc, path, fn
      %Org.Section{} = section ->
        current_properties = section.properties || %{}
        %{section | properties: Map.delete(current_properties, key)}

      _ ->
        raise ArgumentError, "Can only remove properties from sections"
    end)
  end

  @doc """
  Adds metadata (SCHEDULED, DEADLINE, CLOSED) to a section.

  ## Examples

      iex> doc = Org.load_string("* Task")
      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon>")
      iex> doc = Org.add_metadata(doc, ["Task"], :scheduled, timestamp)
      iex> task = Org.section(doc, ["Task"])
      iex> task.metadata.scheduled.date
      ~D[2024-01-15]
  """
  @spec add_metadata(Org.Document.t(), [String.t()], atom(), Org.Timestamp.t()) :: Org.Document.t()
  def add_metadata(doc, path, key, timestamp) when key in [:scheduled, :deadline, :closed] do
    Org.Writer.update_node(doc, path, fn
      %Org.Section{} = section ->
        current_metadata = section.metadata || %{}
        %{section | metadata: Map.put(current_metadata, key, timestamp)}

      _ ->
        raise ArgumentError, "Can only add metadata to sections"
    end)
  end

  @doc """
  Sets multiple metadata entries on a section, replacing existing metadata.

  ## Examples

      iex> doc = Org.load_string("* Task")
      iex> {:ok, scheduled} = Org.Timestamp.parse("<2024-01-15 Mon>")
      iex> {:ok, deadline} = Org.Timestamp.parse("<2024-01-20 Sat>")
      iex> metadata = %{scheduled: scheduled, deadline: deadline}
      iex> doc = Org.set_metadata(doc, ["Task"], metadata)
      iex> task = Org.section(doc, ["Task"])
      iex> task.metadata.scheduled.date
      ~D[2024-01-15]
  """
  @spec set_metadata(Org.Document.t(), [String.t()], %{atom() => Org.Timestamp.t()}) :: Org.Document.t()
  def set_metadata(doc, path, metadata) when is_map(metadata) do
    Org.Writer.update_node(doc, path, fn
      %Org.Section{} = section ->
        %{section | metadata: metadata}

      _ ->
        raise ArgumentError, "Can only set metadata on sections"
    end)
  end

  @doc """
  Updates metadata on a section by merging with existing metadata.

  ## Examples

      iex> doc = Org.load_string("* Task")
      iex> {:ok, scheduled} = Org.Timestamp.parse("<2024-01-15 Mon>")
      iex> doc = Org.add_metadata(doc, ["Task"], :scheduled, scheduled)
      iex> {:ok, deadline} = Org.Timestamp.parse("<2024-01-20 Sat>")
      iex> doc = Org.update_metadata(doc, ["Task"], %{deadline: deadline})
      iex> task = Org.section(doc, ["Task"])
      iex> task.metadata.scheduled.date
      ~D[2024-01-15]
      iex> task.metadata.deadline.date
      ~D[2024-01-20]
  """
  @spec update_metadata(Org.Document.t(), [String.t()], %{atom() => Org.Timestamp.t()}) :: Org.Document.t()
  def update_metadata(doc, path, new_metadata) when is_map(new_metadata) do
    Org.Writer.update_node(doc, path, fn
      %Org.Section{} = section ->
        current_metadata = section.metadata || %{}
        %{section | metadata: Map.merge(current_metadata, new_metadata)}

      _ ->
        raise ArgumentError, "Can only update metadata on sections"
    end)
  end

  @doc """
  Removes metadata from a section.

  ## Examples

      iex> doc = Org.load_string("* Task")
      iex> {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon>")
      iex> doc = Org.add_metadata(doc, ["Task"], :scheduled, timestamp)
      iex> doc = Org.remove_metadata(doc, ["Task"], :scheduled)
      iex> task = Org.section(doc, ["Task"])
      iex> task.metadata[:scheduled]
      nil
  """
  @spec remove_metadata(Org.Document.t(), [String.t()], atom()) :: Org.Document.t()
  def remove_metadata(doc, path, key) do
    Org.Writer.update_node(doc, path, fn
      %Org.Section{} = section ->
        current_metadata = section.metadata || %{}
        %{section | metadata: Map.delete(current_metadata, key)}

      _ ->
        raise ArgumentError, "Can only remove metadata from sections"
    end)
  end

  # Helper functions for repeater functionality

  defp get_repeating_timestamps(section) do
    section.metadata
    |> Enum.filter(fn {_key, value} ->
      case value do
        %Org.Timestamp{repeater: %{}} -> true
        _ -> false
      end
    end)
  end
end
