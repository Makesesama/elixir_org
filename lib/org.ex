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
end
