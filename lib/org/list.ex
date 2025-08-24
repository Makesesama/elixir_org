defmodule Org.List.Item do
  @moduledoc """
  Represents a single item in a list.
  """

  defstruct content: "", indent: 0, ordered: false, number: nil, children: []

  @type t :: %Org.List.Item{
          content: String.t(),
          indent: non_neg_integer(),
          ordered: boolean(),
          number: integer() | nil,
          children: list(Org.List.Item.t())
        }
end

defmodule Org.List do
  @moduledoc """
  Represents a list (ordered or unordered) in an org document.

  Lists can contain nested items and support both bullet points (-) and
  numbered items (1., 2., etc.).

  Example:
      iex> source = "- First item\\n  - Nested item\\n- Second item"
      iex> doc = Org.Parser.parse(source)
      iex> [list] = Org.lists(doc)
      iex> length(list.items)
      3
      iex> Enum.at(list.items, 0).content
      "First item"
      iex> Enum.at(list.items, 0).ordered
      false
  """

  defstruct items: []

  @type t :: %Org.List{items: list(Org.List.Item.t())}

  @doc """
  Creates a new list with given items.
  """
  @spec new(list(Org.List.Item.t())) :: t()
  def new(items) do
    %Org.List{items: items}
  end

  @doc """
  Prepends an item to the list.

  This function is used by the parser, which builds up documents in reverse and then finally
  calls Org.Content.reverse_recursive/1 to yield the original order.
  """
  @spec prepend_item(t(), Org.List.Item.t()) :: t()
  def prepend_item(list, item) do
    %Org.List{list | items: [item | list.items]}
  end

  @doc """
  Converts a flat list of items with indentation into a nested structure.
  """
  @spec build_nested(list(Org.List.Item.t())) :: list(Org.List.Item.t())
  def build_nested([]), do: []

  def build_nested([first | rest]) do
    {children, remaining} = extract_children(rest, first.indent)
    nested_children = build_nested(children)
    item = %{first | children: nested_children}
    [item | build_nested(remaining)]
  end

  defp extract_children(items, parent_indent) do
    extract_children(items, parent_indent, [])
  end

  defp extract_children([], _parent_indent, acc) do
    {Enum.reverse(acc), []}
  end

  defp extract_children([item | rest], parent_indent, acc) do
    if item.indent > parent_indent do
      extract_children(rest, parent_indent, [item | acc])
    else
      {Enum.reverse(acc), [item | rest]}
    end
  end
end

defimpl Org.Content, for: Org.List do
  def reverse_recursive(list) do
    reversed_items =
      list.items
      |> Enum.reverse()
      |> Enum.map(&reverse_item/1)

    %Org.List{list | items: reversed_items}
  end

  defp reverse_item(item) do
    %{item | children: Enum.reverse(item.children) |> Enum.map(&reverse_item/1)}
  end
end
