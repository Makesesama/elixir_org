defmodule Org.NodeFinder do
  @moduledoc """
  Provides functionality to find and navigate nodes in an Org document tree.

  Supports finding nodes by:
  - Path (list of section titles)
  - ID (if sections have IDs)
  - Predicates (custom matching functions)
  - Content type
  """

  @doc """
  Finds a node at the given path in the document tree.

  Path can be:
  - A list of section titles: ["Parent", "Child", "Grandchild"]
  - A list with indices: ["Parent", {:child, 0}, "Grandchild"] (for nth child)
  - A mixed path: ["Parent", {:content, 2}] (for the 3rd content item)

  ## Examples

      iex> doc = Org.Parser.parse("* Parent\\n** Child\\nContent")
      iex> node = Org.NodeFinder.find_by_path(doc, ["Parent", "Child"])
      iex> node.title
      "Child"
  """
  def find_by_path(%Org.Document{} = doc, []), do: doc

  def find_by_path(%Org.Document{sections: sections, contents: contents}, [first | rest]) do
    case first do
      {:section, index} when is_integer(index) ->
        section = Enum.at(sections, index)
        if section, do: find_by_path(section, rest), else: nil

      {:content, index} when is_integer(index) ->
        Enum.at(contents, index)

      title when is_binary(title) ->
        find_section_by_title(sections, title, rest)
    end
  end

  def find_by_path(%Org.Section{} = section, []), do: section

  def find_by_path(%Org.Section{children: children, contents: contents}, [first | rest]) do
    case first do
      {:child, index} when is_integer(index) ->
        child = Enum.at(children, index)
        if child, do: find_by_path(child, rest), else: nil

      {:content, index} when is_integer(index) ->
        Enum.at(contents, index)

      title when is_binary(title) ->
        find_child_by_title(children, title, rest)
    end
  end

  def find_by_path(_, _), do: nil

  @doc """
  Finds all nodes matching a predicate function.

  ## Examples

      iex> doc = Org.Parser.parse("* TODO Task\\n* DONE Complete\\n* Another")
      iex> todos = Org.NodeFinder.find_all(doc, fn 
      ...>   %Org.Section{todo_keyword: "TODO"} -> true
      ...>   _ -> false
      ...> end)
      iex> length(todos)
      1
  """
  def find_all(%Org.Document{} = doc, predicate) when is_function(predicate, 1) do
    find_all_in_node(doc, predicate, [])
  end

  def find_all(%Org.Section{} = section, predicate) when is_function(predicate, 1) do
    find_all_in_node(section, predicate, [])
  end

  defp find_all_in_node(%Org.Document{sections: sections, contents: contents}, predicate, acc) do
    acc = if predicate.(%Org.Document{}), do: [%Org.Document{} | acc], else: acc

    acc =
      contents
      |> Enum.filter(predicate)
      |> Enum.concat(acc)

    sections
    |> Enum.reduce(acc, fn section, acc ->
      find_all_in_node(section, predicate, acc)
    end)
  end

  defp find_all_in_node(%Org.Section{children: children, contents: contents} = section, predicate, acc) do
    acc = if predicate.(section), do: [section | acc], else: acc

    acc =
      contents
      |> Enum.filter(predicate)
      |> Enum.concat(acc)

    children
    |> Enum.reduce(acc, fn child, acc ->
      find_all_in_node(child, predicate, acc)
    end)
  end

  defp find_all_in_node(node, predicate, acc) do
    if predicate.(node), do: [node | acc], else: acc
  end

  @doc """
  Finds the parent of a given node in the document tree.

  Returns `{parent, index}` where index is the position of the node in its parent's children/contents.
  """
  def find_parent(%Org.Document{} = doc, target_node) do
    find_parent_in_node(doc, target_node, nil)
  end

  defp find_parent_in_node(%Org.Document{sections: sections, contents: contents} = doc, target, _parent) do
    # Check if target is in sections
    case Enum.find_index(sections, &(&1 == target)) do
      nil ->
        # Check if target is in contents
        find_target_in_contents_or_sections(contents, sections, target, doc)

      index ->
        {doc, {:section, index}}
    end
  end

  defp find_parent_in_node(%Org.Section{children: children, contents: contents} = section, target, _parent) do
    # Check if target is in children
    case Enum.find_index(children, &(&1 == target)) do
      nil ->
        # Check if target is in contents
        find_target_in_contents_or_children(contents, children, target, section)

      index ->
        {section, {:child, index}}
    end
  end

  defp find_parent_in_node(_, _, _), do: nil

  @doc """
  Generates a path to a given node from the document root.

  Returns a list that can be used with `find_by_path/2`.
  """
  def path_to_node(%Org.Document{} = doc, target_node) do
    build_path(doc, target_node, [])
  end

  defp build_path(current, target, path) when current == target do
    Enum.reverse(path)
  end

  defp build_path(%Org.Document{sections: sections}, target, path) do
    Enum.find_value(sections, fn section ->
      build_path(section, target, [section.title | path])
    end)
  end

  defp build_path(%Org.Section{children: children}, target, path) do
    Enum.find_value(children, fn child ->
      build_path(child, target, [child.title | path])
    end)
  end

  defp build_path(_, _, _), do: nil

  @doc """
  Walks the entire document tree, calling a function on each node.

  The function receives the node and its path from the root.
  """
  def walk(%Org.Document{} = doc, fun) when is_function(fun, 2) do
    walk_node(doc, [], fun)
  end

  defp walk_node(%Org.Document{sections: sections, contents: contents} = doc, path, fun) do
    fun.(doc, path)

    Enum.each(contents, fn content ->
      fun.(content, path ++ [{:content, content}])
    end)

    Enum.each(sections, fn section ->
      walk_node(section, path ++ [section.title], fun)
    end)
  end

  defp walk_node(%Org.Section{children: children, contents: contents} = section, path, fun) do
    fun.(section, path)

    Enum.each(contents, fn content ->
      fun.(content, path ++ [{:content, content}])
    end)

    Enum.each(children, fn child ->
      walk_node(child, path ++ [child.title], fun)
    end)
  end

  defp walk_node(node, path, fun) do
    fun.(node, path)
  end

  # Helper functions to reduce nesting depth

  defp find_section_by_title(sections, title, rest) do
    case Enum.find(sections, fn s -> s.title == title end) do
      nil -> nil
      section -> find_by_path(section, rest)
    end
  end

  defp find_child_by_title(children, title, rest) do
    case Enum.find(children, fn c -> c.title == title end) do
      nil -> nil
      child -> find_by_path(child, rest)
    end
  end

  defp find_target_in_contents_or_sections(contents, sections, target, doc) do
    case Enum.find_index(contents, &(&1 == target)) do
      nil ->
        # Search recursively in sections
        Enum.find_value(sections, fn section ->
          find_parent_in_node(section, target, doc)
        end)

      index ->
        {doc, {:content, index}}
    end
  end

  defp find_target_in_contents_or_children(contents, children, target, section) do
    case Enum.find_index(contents, &(&1 == target)) do
      nil ->
        # Search recursively in children
        Enum.find_value(children, fn child ->
          find_parent_in_node(child, target, section)
        end)

      index ->
        {section, {:content, index}}
    end
  end
end
