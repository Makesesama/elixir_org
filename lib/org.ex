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
    Org.Parser.parse(data)
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
end
