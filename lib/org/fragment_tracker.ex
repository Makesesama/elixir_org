defmodule Org.FragmentTracker do
  @moduledoc """
  Tracks fragments within a document for efficient incremental parsing and updates.

  This module maintains a mapping between fragments and their positions in the
  source text, allowing for precise editing operations while preserving formatting.

  ## Features

  - Position tracking for all fragments
  - Incremental update detection
  - Efficient range-based queries
  - Context preservation during edits
  """

  alias Org.FragmentParser

  @type fragment_id :: String.t()
  @type position :: FragmentParser.position()
  @type range :: FragmentParser.range()

  @type tracked_fragment :: %{
          id: fragment_id(),
          fragment: FragmentParser.fragment(),
          parent_id: fragment_id() | nil,
          children_ids: [fragment_id()],
          dirty: boolean()
        }

  @type fragment_tracker :: %{
          fragments: %{fragment_id() => tracked_fragment()},
          position_index: %{position() => fragment_id()},
          range_index: [{range(), fragment_id()}],
          source_text: String.t(),
          next_id: non_neg_integer()
        }

  @doc """
  Creates a new fragment tracker from source text.

  ## Examples

      iex> text = "* Section 1\\n\\nParagraph\\n\\n* Section 2"
      iex> tracker = Org.FragmentTracker.new(text)
      iex> map_size(tracker.fragments) > 0
      true
  """
  @spec new(String.t()) :: fragment_tracker()
  def new(source_text) do
    fragments = parse_all_fragments(source_text)

    {fragment_map, position_index, range_index} =
      fragments
      |> Enum.with_index()
      |> Enum.reduce({%{}, %{}, []}, fn {fragment, index}, {fmap, pindex, rindex} ->
        id = "fragment_#{index}"

        tracked = %{
          id: id,
          fragment: fragment,
          parent_id: nil,
          children_ids: [],
          dirty: false
        }

        {start_pos, _end_pos} = fragment.range

        new_fmap = Map.put(fmap, id, tracked)
        new_pindex = Map.put(pindex, start_pos, id)
        new_rindex = [{fragment.range, id} | rindex]

        {new_fmap, new_pindex, new_rindex}
      end)

    %{
      fragments: fragment_map,
      position_index: position_index,
      range_index: Enum.sort(range_index, &compare_ranges/2),
      source_text: source_text,
      next_id: map_size(fragment_map)
    }
  end

  @doc """
  Updates a fragment by ID with new text content.

  Returns an updated tracker with position information recalculated.

  ## Examples

      iex> tracker = Org.FragmentTracker.new("* Old Title\\nContent")
      iex> [id | _] = Map.keys(tracker.fragments)
      iex> updated_tracker = Org.FragmentTracker.update_fragment(tracker, id, "* New Title")
      iex> fragment = updated_tracker.fragments[id].fragment
      iex> fragment.content.title
      "New Title"
  """
  @spec update_fragment(fragment_tracker(), fragment_id(), String.t()) :: fragment_tracker()
  def update_fragment(tracker, fragment_id, new_text) do
    case Map.get(tracker.fragments, fragment_id) do
      nil ->
        tracker

      tracked_fragment ->
        old_fragment = tracked_fragment.fragment
        updated_fragment = FragmentParser.update_fragment(old_fragment, new_text)

        # Mark as dirty and update
        updated_tracked = %{tracked_fragment | fragment: updated_fragment, dirty: true}

        updated_fragments = Map.put(tracker.fragments, fragment_id, updated_tracked)

        # Recalculate positions if range changed
        %{tracker | fragments: updated_fragments}
        |> maybe_recalculate_positions(fragment_id, old_fragment.range, updated_fragment.range)
    end
  end

  @doc """
  Inserts a new fragment at the specified position.

  ## Examples

      iex> tracker = Org.FragmentTracker.new("* Section")
      iex> new_tracker = Org.FragmentTracker.insert_fragment(tracker, {2, 1}, "New content line")
      iex> map_size(new_tracker.fragments) > map_size(tracker.fragments)
      true
  """
  @spec insert_fragment(fragment_tracker(), position(), String.t()) :: fragment_tracker()
  def insert_fragment(tracker, position, text) do
    fragment = FragmentParser.parse_fragment(text, start_position: position)
    fragment_id = "fragment_#{tracker.next_id}"

    tracked_fragment = %{
      id: fragment_id,
      fragment: fragment,
      parent_id: find_parent_fragment_id(tracker, position),
      children_ids: [],
      dirty: true
    }

    updated_fragments = Map.put(tracker.fragments, fragment_id, tracked_fragment)
    {start_pos, _} = fragment.range
    updated_position_index = Map.put(tracker.position_index, start_pos, fragment_id)
    updated_range_index = [{fragment.range, fragment_id} | tracker.range_index]

    %{
      tracker
      | fragments: updated_fragments,
        position_index: updated_position_index,
        range_index: Enum.sort(updated_range_index, &compare_ranges/2),
        next_id: tracker.next_id + 1
    }
  end

  @doc """
  Removes a fragment by ID.

  ## Examples

      iex> tracker = Org.FragmentTracker.new("* Section 1\\n* Section 2")
      iex> [id | _] = Map.keys(tracker.fragments)
      iex> updated_tracker = Org.FragmentTracker.remove_fragment(tracker, id)
      iex> Map.has_key?(updated_tracker.fragments, id)
      false
  """
  @spec remove_fragment(fragment_tracker(), fragment_id()) :: fragment_tracker()
  def remove_fragment(tracker, fragment_id) do
    case Map.get(tracker.fragments, fragment_id) do
      nil ->
        tracker

      tracked_fragment ->
        # Remove from fragments map
        updated_fragments = Map.delete(tracker.fragments, fragment_id)

        # Remove from position index
        {start_pos, _} = tracked_fragment.fragment.range
        updated_position_index = Map.delete(tracker.position_index, start_pos)

        # Remove from range index
        updated_range_index =
          Enum.reject(tracker.range_index, fn {_range, id} -> id == fragment_id end)

        %{
          tracker
          | fragments: updated_fragments,
            position_index: updated_position_index,
            range_index: updated_range_index
        }
    end
  end

  @doc """
  Finds fragments that overlap with the given range.

  ## Examples

      iex> tracker = Org.FragmentTracker.new("* Section\\nContent\\n* Another")
      iex> overlapping = Org.FragmentTracker.find_fragments_in_range(tracker, {{1, 1}, {2, 10}})
      iex> length(overlapping) > 0
      true
  """
  @spec find_fragments_in_range(fragment_tracker(), range()) :: [tracked_fragment()]
  def find_fragments_in_range(tracker, query_range) do
    tracker.range_index
    |> Enum.filter(fn {fragment_range, _id} ->
      ranges_overlap?(fragment_range, query_range)
    end)
    |> Enum.map(fn {_range, id} -> tracker.fragments[id] end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Finds the fragment at a specific position.

  ## Examples

      iex> tracker = Org.FragmentTracker.new("* Section\\nContent")
      iex> fragment = Org.FragmentTracker.find_fragment_at_position(tracker, {1, 2})
      iex> fragment != nil
      true
  """
  @spec find_fragment_at_position(fragment_tracker(), position()) :: tracked_fragment() | nil
  def find_fragment_at_position(tracker, position) do
    # First try direct lookup
    case Map.get(tracker.position_index, position) do
      nil ->
        # Search through ranges to find containing fragment
        tracker.range_index
        |> Enum.find(fn {range, _id} ->
          position_in_range?(position, range)
        end)
        |> case do
          {_range, id} -> tracker.fragments[id]
          nil -> nil
        end

      id ->
        tracker.fragments[id]
    end
  end

  @doc """
  Gets all dirty fragments (those that have been modified).

  ## Examples

      iex> tracker = Org.FragmentTracker.new("* Section")
      iex> [id | _] = Map.keys(tracker.fragments)
      iex> updated = Org.FragmentTracker.update_fragment(tracker, id, "* Updated")
      iex> dirty = Org.FragmentTracker.get_dirty_fragments(updated)
      iex> length(dirty) > 0
      true
  """
  @spec get_dirty_fragments(fragment_tracker()) :: [tracked_fragment()]
  def get_dirty_fragments(tracker) do
    tracker.fragments
    |> Map.values()
    |> Enum.filter(& &1.dirty)
  end

  @doc """
  Marks a fragment as clean (not dirty).
  """
  @spec mark_fragment_clean(fragment_tracker(), fragment_id()) :: fragment_tracker()
  def mark_fragment_clean(tracker, fragment_id) do
    case Map.get(tracker.fragments, fragment_id) do
      nil ->
        tracker

      tracked_fragment ->
        updated_fragment = %{tracked_fragment | dirty: false}
        updated_fragments = Map.put(tracker.fragments, fragment_id, updated_fragment)
        %{tracker | fragments: updated_fragments}
    end
  end

  @doc """
  Regenerates the source text from all fragments.

  This is useful after making edits to see the complete updated text.
  """
  @spec regenerate_source(fragment_tracker()) :: String.t()
  def regenerate_source(tracker) do
    tracker.range_index
    |> Enum.sort(&compare_ranges/2)
    |> Enum.map_join("\n", fn {_range, id} ->
      FragmentParser.render_fragment(tracker.fragments[id].fragment)
    end)
  end

  # Private functions

  defp parse_all_fragments(source_text) do
    FragmentParser.parse_fragments(source_text)
  end

  defp compare_ranges({{line1, col1}, _}, {{line2, col2}, _}) do
    if line1 == line2 do
      col1 <= col2
    else
      line1 < line2
    end
  end

  defp ranges_overlap?(
         {{start1_line, start1_col}, {end1_line, end1_col}},
         {{start2_line, start2_col}, {end2_line, end2_col}}
       ) do
    # Convert to single number for easier comparison
    start1 = start1_line * 10_000 + start1_col
    end1 = end1_line * 10_000 + end1_col
    start2 = start2_line * 10_000 + start2_col
    end2 = end2_line * 10_000 + end2_col

    not (end1 < start2 or end2 < start1)
  end

  defp position_in_range?({line, col}, {{start_line, start_col}, {end_line, end_col}}) do
    pos = line * 10_000 + col
    start_pos = start_line * 10_000 + start_col
    end_pos = end_line * 10_000 + end_col

    pos >= start_pos and pos <= end_pos
  end

  defp find_parent_fragment_id(tracker, position) do
    # Find the smallest fragment that contains this position
    tracker.range_index
    |> Enum.filter(fn {range, _id} ->
      position_in_range?(position, range)
    end)
    |> Enum.min_by(
      fn {{{start_line, start_col}, {end_line, end_col}}, _id} ->
        # Smaller range = more specific parent
        (end_line - start_line) * 10_000 + (end_col - start_col)
      end,
      fn -> nil end
    )
    |> case do
      {_range, id} -> id
      nil -> nil
    end
  end

  defp maybe_recalculate_positions(tracker, fragment_id, old_range, new_range) do
    if old_range != new_range do
      do_recalculate_positions(tracker, fragment_id, old_range, new_range)
    else
      tracker
    end
  end

  defp do_recalculate_positions(tracker, fragment_id, old_range, new_range) do
    # Remove old position entry
    {old_start_pos, _} = old_range
    updated_position_index = Map.delete(tracker.position_index, old_start_pos)

    # Add new position entry
    {new_start_pos, _} = new_range
    updated_position_index = Map.put(updated_position_index, new_start_pos, fragment_id)

    # Update range index
    updated_range_index = update_range_index(tracker.range_index, fragment_id, new_range)

    %{tracker | position_index: updated_position_index, range_index: updated_range_index}
  end

  defp update_range_index(range_index, fragment_id, new_range) do
    range_index
    |> Enum.map(fn {range, id} ->
      if id == fragment_id do
        {new_range, id}
      else
        {range, id}
      end
    end)
    |> Enum.sort(&compare_ranges/2)
  end
end
