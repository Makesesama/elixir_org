defmodule Org.Section do
  defstruct title: "", todo_keyword: nil, children: [], contents: []

  @moduledoc ~S"""
  Represents a section of a document with a title, optional TODO keyword, and possible contents & subsections.

  Example:
      iex> source = "* TODO Hello\nWorld\n** DONE What's up?\nNothing much.\n** How's it going?\nAll fine, how are you?\n"
      iex> doc = Org.Parser.parse(source)
      iex> section = Org.section(doc, ["Hello"])
      iex> section.todo_keyword
      "TODO"
      iex> section.contents
      [%Org.Paragraph{lines: ["World"]}]
      iex> length(section.children)
      2
      iex> for child <- section.children, do: {child.title, child.todo_keyword}
      [{"What's up?", "DONE"}, {"How's it going?", nil}]
  """

  @type t :: %Org.Section{
    title: String.t,
    todo_keyword: String.t | nil,
    children: list(Org.Section.t),
    contents: list(Org.Content.t),
  }

  def add_nested(parent, 1, child) do
    %Org.Section{parent | children: [child | parent.children]}
  end

  def add_nested(parent, level, child) do
    {first, rest} = case parent.children do
                      [first | rest] -> {first, rest}
                      [] -> {%Org.Section{}, []}
                    end
    %Org.Section{parent | children: [add_nested(first, level - 1, child) | rest]}
  end

  def reverse_recursive(section) do
    %Org.Section{
      section |
      children: Enum.reverse(Enum.map(section.children, &reverse_recursive/1)),
      contents: Enum.reverse(Enum.map(section.contents, &Org.Content.reverse_recursive/1)),
    }
  end

  def find_by_path(_, []) do
    raise "BUG: can't find section with empty path!"
  end

  def find_by_path([], path) do
    raise "Section not found with remaining path: #{inspect path}"
  end

  def find_by_path([%Org.Section{title: title} = matching_section | _], [title]) do
    matching_section
  end

  def find_by_path([%Org.Section{title: title} = matching_section | _], [title | rest_path]) do
    find_by_path(matching_section.children, rest_path)
  end

  def find_by_path([_ | rest], path) do
    find_by_path(rest, path)
  end

  def contents(%Org.Section{contents: contents}) do
    contents
  end

  @doc "Adds content to the last prepended section"
  def prepend_content(%Org.Section{children: []} = section, content) do
    %Org.Section{section | contents: [content | section.contents]}
  end

  def prepend_content(%Org.Section{children: [current_child | children]} = section, content) do
    %Org.Section{section | children: [prepend_content(current_child, content) | children]}
  end

  def update_content(%Org.Section{children: [], contents: [current_content | rest]} = section, updater) do
    %Org.Section{section | contents: [updater.(current_content) | rest]}
  end

  def update_content(%Org.Section{children: [current_section | rest]} = section, updater) do
    %Org.Section{section | children: [update_content(current_section, updater) | rest]}
  end
end
