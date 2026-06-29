defmodule Org.PathSegment do
  @moduledoc """
  Resolves a single path segment to one sibling section, supporting
  occurrence-based addressing for duplicate-title headings.

  A path segment may be:

  - a binary title (`"Task"`) — resolves to the **first** sibling whose title
    matches. This is the historical behaviour.
  - a `{title, index}` tuple (`{"Task", 1}`) — resolves to the `index`-th
    (0-based) sibling among those whose title equals `title`. This makes
    same-title siblings individually addressable.

  Indices are 0-based to match the existing `{:section, n}` / `{:child, n}`
  absolute-index segments used by `Org.NodeFinder.find_by_path/2`.
  """

  @doc """
  Returns the index in `sections` of the section selected by `segment`,
  or `nil` when nothing matches.

  ## Examples

      iex> sections = [%Org.Section{title: "A"}, %Org.Section{title: "A"}]
      iex> Org.PathSegment.resolve_index(sections, "A")
      0
      iex> Org.PathSegment.resolve_index(sections, {"A", 1})
      1
      iex> Org.PathSegment.resolve_index(sections, {"A", 2})
      nil
      iex> Org.PathSegment.resolve_index(sections, "Missing")
      nil
  """
  @spec resolve_index([Org.Section.t()], String.t() | {String.t(), non_neg_integer()}) ::
          non_neg_integer() | nil
  def resolve_index(sections, title) when is_binary(title) do
    Enum.find_index(sections, fn s -> match_title?(s, title) end)
  end

  def resolve_index(sections, {title, index})
      when is_binary(title) and is_integer(index) and index >= 0 do
    sections
    |> Enum.with_index()
    |> Enum.filter(fn {s, _i} -> match_title?(s, title) end)
    |> Enum.at(index)
    |> case do
      {_section, i} -> i
      nil -> nil
    end
  end

  @doc """
  Returns true when `segment` is a recognised path segment for occurrence-based
  addressing (a binary title or a `{title, index}` tuple).
  """
  @spec title_segment?(term()) :: boolean()
  def title_segment?(title) when is_binary(title), do: true

  def title_segment?({title, index}) when is_binary(title) and is_integer(index) and index >= 0,
    do: true

  def title_segment?(_), do: false

  defp match_title?(%Org.Section{title: title}, title), do: true
  defp match_title?(_, _), do: false
end
