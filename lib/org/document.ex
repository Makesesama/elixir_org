defmodule Org.Document do
  defstruct comments: [], sections: [], contents: [], file_properties: %{}

  @type t :: %Org.Document{
          comments: list(String.t()),
          sections: list(Org.Section.t()),
          contents: list(Org.Content.t()),
          file_properties: %{String.t() => String.t()}
        }

  @moduledoc ~S"""
  Represents an interpreted document.

  Documents are organized as a tree of sections, each of which has a title and optional contents.
  The document can also have contents at the top level.
  """

  @doc "Retrieve current contents of document"
  def contents(%Org.Document{contents: contents}) do
    contents
  end

  @doc "Prepend a comment to the list of comments. Used by the parser"
  def add_comment(doc, comment) do
    %Org.Document{doc | comments: [comment | doc.comments]}
  end

  @doc "Prepend a subsection at the given level with optional TODO keyword, priority, and tags."
  def add_subsection(doc, level, title, todo_keyword \\ nil, priority \\ nil, tags \\ [])

  def add_subsection(doc, 1, title, todo_keyword, priority, tags) do
    # For top-level sections, inherit from file tags
    file_tags = get_file_tags(doc)
    all_tags = (file_tags ++ tags) |> Enum.uniq()

    %Org.Document{
      doc
      | sections: [
          %Org.Section{title: title, todo_keyword: todo_keyword, priority: priority, tags: all_tags} | doc.sections
        ]
    }
  end

  def add_subsection(doc, level, title, todo_keyword, priority, tags) do
    {current, rest} =
      case doc.sections do
        [current | rest] -> {current, rest}
        [] -> {%Org.Section{}, []}
      end

    # For nested sections, we need to calculate inherited tags
    parent_tags = get_parent_tags_for_level(current, level - 1)
    all_tags = (parent_tags ++ tags) |> Enum.uniq()

    %Org.Document{
      doc
      | sections: [
          Org.Section.add_nested(current, level - 1, %Org.Section{
            title: title,
            todo_keyword: todo_keyword,
            priority: priority,
            tags: all_tags
          })
          | rest
        ]
    }
  end

  # Helper functions for tag inheritance

  defp get_file_tags(doc) do
    case Map.get(doc.file_properties, "FILETAGS") do
      nil -> []
      filetags_string -> parse_file_tags(filetags_string)
    end
  end

  defp parse_file_tags(""), do: []
  defp parse_file_tags(nil), do: []

  defp parse_file_tags(filetags_string) do
    # Handle both space-separated and colon-separated tags
    if String.contains?(filetags_string, ":") do
      # :tag1:tag2:tag3: format
      filetags_string
      |> String.trim()
      |> String.trim_leading(":")
      |> String.trim_trailing(":")
      |> String.split(":")
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.trim/1)
    else
      # space-separated format
      filetags_string
      |> String.split()
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
    end
  end

  defp get_parent_tags_for_level(section, target_level) do
    get_section_tags_at_level(section, target_level, 1)
  end

  defp get_section_tags_at_level(_section, target_level, current_level) when current_level > target_level do
    []
  end

  defp get_section_tags_at_level(section, target_level, current_level) when current_level == target_level do
    section.tags || []
  end

  defp get_section_tags_at_level(section, target_level, current_level) do
    # Need to go deeper into the most recent child
    case section.children do
      [most_recent_child | _] ->
        parent_tags = section.tags || []
        child_tags = get_section_tags_at_level(most_recent_child, target_level, current_level + 1)
        parent_tags ++ child_tags

      [] ->
        []
    end
  end

  @doc """
  Reverses the document's entire content recursively.

  Uses `Org.Section.reverse_recursive/1` and `Org.Content.reverse_recursive/1` to reverse sections and contents.

  Example (comments):
      iex> doc = %Org.Document{}
      iex> doc = Org.Document.add_comment(doc, "first")
      iex> doc = Org.Document.add_comment(doc, "second")
      iex> doc = Org.Document.add_comment(doc, "third")
      iex> doc.comments
      ["third", "second", "first"]
      iex> doc = Org.Document.reverse_recursive(doc)
      iex> doc.comments
      ["first", "second", "third"]

  Example (sections):
      iex> doc = %Org.Document{}
      iex> doc = Org.Document.add_subsection(doc, 1, "First", nil, nil)
      iex> doc = Org.Document.add_subsection(doc, 1, "Second", "TODO", "A")
      iex> doc = Org.Document.add_subsection(doc, 1, "Third", "DONE", "B")
      iex> for %Org.Section{title: title, todo_keyword: todo, priority: priority} <- doc.sections, do: {title, todo, priority}
      [{"Third", "DONE", "B"}, {"Second", "TODO", "A"}, {"First", nil, nil}]
      iex> doc = Org.Document.reverse_recursive(doc)
      iex> for %Org.Section{title: title, todo_keyword: todo, priority: priority} <- doc.sections, do: {title, todo, priority}
      [{"First", nil, nil}, {"Second", "TODO", "A"}, {"Third", "DONE", "B"}]

  Example (contents):
      iex> doc = %Org.Document{}
      iex> doc = Org.Document.prepend_content(doc, %Org.Paragraph{lines: ["first paragraph, first line"]})
      iex> doc = Org.Document.update_content(doc, fn p -> Org.Paragraph.prepend_line(p, "first paragraph, second line") end)
      iex> doc = Org.Document.prepend_content(doc, %Org.Paragraph{lines: ["second paragraph, first line"]})
      iex> doc = Org.Document.update_content(doc, fn p -> Org.Paragraph.prepend_line(p, "second paragraph, second line") end)
      iex> Org.Document.contents(doc)
      [%Org.Paragraph{lines: ["second paragraph, second line", "second paragraph, first line"]},
       %Org.Paragraph{lines: ["first paragraph, second line", "first paragraph, first line"]}]
      iex> doc = Org.Document.reverse_recursive(doc)
      iex> Org.Document.contents(doc)
      [%Org.Paragraph{lines: ["first paragraph, first line", "first paragraph, second line"]},
       %Org.Paragraph{lines: ["second paragraph, first line", "second paragraph, second line"]}]
  """
  def reverse_recursive(doc) do
    %Org.Document{
      doc
      | comments: Enum.reverse(doc.comments),
        sections: Enum.reverse(Enum.map(doc.sections, &Org.Section.reverse_recursive/1)),
        contents: Enum.reverse(Enum.map(doc.contents, &Org.Content.reverse_recursive/1))
    }
  end

  @doc ~S"""
  Prepend content to the currently deepest section, or toplevel if no sections exist.

  See documentation of `reverse_recursive/1` for a usage example.
  """
  def prepend_content(%Org.Document{sections: []} = doc, content) do
    %Org.Document{doc | contents: [content | doc.contents]}
  end

  def prepend_content(%Org.Document{sections: [current_section | rest]} = doc, content) do
    %Org.Document{doc | sections: [Org.Section.prepend_content(current_section, content) | rest]}
  end

  @doc ~S"""
  Update the last prepended content. Yields the content to the given updater.

  See documentation of `reverse_recursive/1` for a usage example.
  """
  def update_content(%Org.Document{sections: [], contents: [current_content | rest]} = doc, updater) do
    %Org.Document{doc | contents: [updater.(current_content) | rest]}
  end

  def update_content(%Org.Document{sections: [current_section | rest]} = doc, updater) do
    %Org.Document{doc | sections: [Org.Section.update_content(current_section, updater) | rest]}
  end
end
