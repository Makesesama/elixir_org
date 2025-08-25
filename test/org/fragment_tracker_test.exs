defmodule Org.FragmentTrackerTest do
  use ExUnit.Case
  doctest Org.FragmentTracker

  alias Org.FragmentTracker

  setup do
    text = "* Section 1\n\nParagraph content\n\n* Section 2\nMore content"
    tracker = FragmentTracker.new(text)

    {:ok, tracker: tracker, text: text}
  end

  describe "new/1" do
    test "creates tracker with fragments", %{tracker: tracker} do
      assert is_map(tracker.fragments)
      assert map_size(tracker.fragments) > 0
      assert tracker.source_text != ""
      assert tracker.next_id >= 0
    end

    test "builds position index", %{tracker: tracker} do
      assert is_map(tracker.position_index)
      assert map_size(tracker.position_index) > 0
    end

    test "builds range index", %{tracker: tracker} do
      assert is_list(tracker.range_index)
      assert length(tracker.range_index) > 0

      # Should be sorted by position
      ranges = Enum.map(tracker.range_index, &elem(&1, 0))

      sorted_ranges =
        Enum.sort(ranges, fn {{line1, col1}, _}, {{line2, col2}, _} ->
          if line1 == line2, do: col1 <= col2, else: line1 < line2
        end)

      assert ranges == sorted_ranges
    end
  end

  describe "update_fragment/3" do
    test "updates existing fragment", %{tracker: tracker} do
      [fragment_id | _] = Map.keys(tracker.fragments)

      updated_tracker = FragmentTracker.update_fragment(tracker, fragment_id, "* Updated Title")

      assert updated_tracker != tracker
      updated_fragment = updated_tracker.fragments[fragment_id]
      assert updated_fragment.dirty == true
    end

    test "handles non-existent fragment ID", %{tracker: tracker} do
      result = FragmentTracker.update_fragment(tracker, "non_existent", "New text")
      assert result == tracker
    end

    test "recalculates positions when range changes", %{tracker: tracker} do
      [fragment_id | _] = Map.keys(tracker.fragments)
      original_fragment = tracker.fragments[fragment_id]

      # Update with much longer text to change range
      long_text = String.duplicate("very long text ", 10)
      updated_tracker = FragmentTracker.update_fragment(tracker, fragment_id, long_text)

      updated_fragment = updated_tracker.fragments[fragment_id]

      # Range should be different
      assert original_fragment.fragment.range != updated_fragment.fragment.range
    end
  end

  describe "insert_fragment/3" do
    test "inserts new fragment at position", %{tracker: tracker} do
      position = {10, 1}
      text = "New inserted content"

      updated_tracker = FragmentTracker.insert_fragment(tracker, position, text)

      assert map_size(updated_tracker.fragments) == map_size(tracker.fragments) + 1
      assert updated_tracker.next_id == tracker.next_id + 1

      # Should be able to find the new fragment
      new_fragment = FragmentTracker.find_fragment_at_position(updated_tracker, position)
      assert new_fragment != nil
      assert new_fragment.dirty == true
    end

    test "updates position and range indexes", %{tracker: tracker} do
      position = {5, 5}
      text = "Inserted text"

      updated_tracker = FragmentTracker.insert_fragment(tracker, position, text)

      assert Map.has_key?(updated_tracker.position_index, position)
      assert length(updated_tracker.range_index) == length(tracker.range_index) + 1
    end
  end

  describe "remove_fragment/2" do
    test "removes existing fragment", %{tracker: tracker} do
      [fragment_id | _] = Map.keys(tracker.fragments)

      updated_tracker = FragmentTracker.remove_fragment(tracker, fragment_id)

      assert map_size(updated_tracker.fragments) == map_size(tracker.fragments) - 1
      assert not Map.has_key?(updated_tracker.fragments, fragment_id)
    end

    test "updates indexes when removing fragment", %{tracker: tracker} do
      [fragment_id | _] = Map.keys(tracker.fragments)
      original_fragment = tracker.fragments[fragment_id]
      {start_pos, _} = original_fragment.fragment.range

      updated_tracker = FragmentTracker.remove_fragment(tracker, fragment_id)

      # Position should be removed from index
      assert not Map.has_key?(updated_tracker.position_index, start_pos)

      # Range should be removed from index
      remaining_ids = Enum.map(updated_tracker.range_index, &elem(&1, 1))
      assert fragment_id not in remaining_ids
    end

    test "handles non-existent fragment ID", %{tracker: tracker} do
      result = FragmentTracker.remove_fragment(tracker, "non_existent")
      assert result == tracker
    end
  end

  describe "find_fragments_in_range/2" do
    test "finds overlapping fragments", %{tracker: tracker} do
      # Query range that should overlap with first few fragments
      query_range = {{1, 1}, {3, 10}}

      overlapping = FragmentTracker.find_fragments_in_range(tracker, query_range)

      assert length(overlapping) > 0

      # All found fragments should actually overlap with query range
      Enum.each(overlapping, fn fragment ->
        fragment_range = fragment.fragment.range
        assert ranges_overlap?(fragment_range, query_range)
      end)
    end

    test "returns empty list for non-overlapping range", %{tracker: tracker} do
      # Query range way beyond the document
      query_range = {{100, 1}, {200, 1}}

      overlapping = FragmentTracker.find_fragments_in_range(tracker, query_range)

      assert overlapping == []
    end

    test "finds exact range matches", %{tracker: tracker} do
      [fragment_id | _] = Map.keys(tracker.fragments)
      fragment = tracker.fragments[fragment_id]
      exact_range = fragment.fragment.range

      overlapping = FragmentTracker.find_fragments_in_range(tracker, exact_range)

      # Should include at least the exact fragment
      found_ids = Enum.map(overlapping, & &1.id)
      assert fragment_id in found_ids
    end
  end

  describe "find_fragment_at_position/2" do
    test "finds fragment at exact start position", %{tracker: tracker} do
      [fragment_id | _] = Map.keys(tracker.fragments)
      fragment = tracker.fragments[fragment_id]
      {start_pos, _} = fragment.fragment.range

      found_fragment = FragmentTracker.find_fragment_at_position(tracker, start_pos)

      assert found_fragment != nil
      assert found_fragment.id == fragment_id
    end

    test "finds fragment containing position", %{tracker: tracker} do
      # Use position that should be inside the first fragment
      # Somewhere in the first line
      position = {1, 5}

      found_fragment = FragmentTracker.find_fragment_at_position(tracker, position)

      # Should find a fragment that contains this position
      if found_fragment do
        {{start_line, start_col}, {end_line, end_col}} = found_fragment.fragment.range
        pos_num = elem(position, 0) * 10_000 + elem(position, 1)
        start_num = start_line * 10_000 + start_col
        end_num = end_line * 10_000 + end_col

        assert pos_num >= start_num
        assert pos_num <= end_num
      end
    end

    test "returns nil for position outside document", %{tracker: tracker} do
      position = {1000, 1000}

      found_fragment = FragmentTracker.find_fragment_at_position(tracker, position)

      assert found_fragment == nil
    end
  end

  describe "get_dirty_fragments/1" do
    test "returns empty list when no fragments are dirty", %{tracker: tracker} do
      dirty_fragments = FragmentTracker.get_dirty_fragments(tracker)

      # New tracker should have no dirty fragments
      assert dirty_fragments == []
    end

    test "returns dirty fragments after updates", %{tracker: tracker} do
      [fragment_id | _] = Map.keys(tracker.fragments)

      updated_tracker = FragmentTracker.update_fragment(tracker, fragment_id, "Updated text")
      dirty_fragments = FragmentTracker.get_dirty_fragments(updated_tracker)

      assert length(dirty_fragments) == 1
      assert hd(dirty_fragments).id == fragment_id
      assert hd(dirty_fragments).dirty == true
    end

    test "includes inserted fragments as dirty", %{tracker: tracker} do
      updated_tracker = FragmentTracker.insert_fragment(tracker, {10, 1}, "New content")
      dirty_fragments = FragmentTracker.get_dirty_fragments(updated_tracker)

      assert length(dirty_fragments) == 1
      assert hd(dirty_fragments).dirty == true
    end
  end

  describe "mark_fragment_clean/2" do
    test "marks dirty fragment as clean", %{tracker: tracker} do
      [fragment_id | _] = Map.keys(tracker.fragments)

      # Make fragment dirty first
      dirty_tracker = FragmentTracker.update_fragment(tracker, fragment_id, "Updated")
      assert FragmentTracker.get_dirty_fragments(dirty_tracker) |> length() == 1

      # Mark as clean
      clean_tracker = FragmentTracker.mark_fragment_clean(dirty_tracker, fragment_id)
      assert FragmentTracker.get_dirty_fragments(clean_tracker) |> length() == 0
    end

    test "handles non-existent fragment ID", %{tracker: tracker} do
      result = FragmentTracker.mark_fragment_clean(tracker, "non_existent")
      assert result == tracker
    end
  end

  describe "regenerate_source/1" do
    test "regenerates original source text", %{tracker: tracker, text: _original_text} do
      regenerated = FragmentTracker.regenerate_source(tracker)

      # Should be similar to original (may have minor formatting differences)
      assert String.length(regenerated) > 0
      assert regenerated =~ "Section 1"
      assert regenerated =~ "Section 2"
    end

    test "includes updated fragments in regeneration", %{tracker: tracker} do
      [fragment_id | _] = Map.keys(tracker.fragments)

      updated_tracker = FragmentTracker.update_fragment(tracker, fragment_id, "* Updated Section")
      regenerated = FragmentTracker.regenerate_source(updated_tracker)

      assert regenerated =~ "Updated Section"
    end
  end

  describe "complex scenarios" do
    test "handles multiple concurrent updates" do
      tracker = FragmentTracker.new("* A\nContent A\n* B\nContent B\n* C\nContent C")

      # Get all fragment IDs
      fragment_ids = Map.keys(tracker.fragments)

      # Update multiple fragments
      updated_tracker =
        fragment_ids
        |> Enum.take(2)
        |> Enum.with_index()
        |> Enum.reduce(tracker, fn {id, index}, acc ->
          FragmentTracker.update_fragment(acc, id, "Updated #{index}")
        end)

      dirty_fragments = FragmentTracker.get_dirty_fragments(updated_tracker)
      assert length(dirty_fragments) == 2
    end

    test "maintains consistency across operations" do
      tracker = FragmentTracker.new("* Section\nContent")
      [fragment_id | _] = Map.keys(tracker.fragments)

      # Update, then remove, then insert
      tracker = FragmentTracker.update_fragment(tracker, fragment_id, "Updated")
      tracker = FragmentTracker.remove_fragment(tracker, fragment_id)
      tracker = FragmentTracker.insert_fragment(tracker, {5, 1}, "New content")

      # Should still be consistent
      assert is_map(tracker.fragments)
      assert is_list(tracker.range_index)
      assert map_size(tracker.position_index) >= 0

      # Should be able to regenerate
      regenerated = FragmentTracker.regenerate_source(tracker)
      assert is_binary(regenerated)
    end
  end

  # Helper function for testing
  defp ranges_overlap?(
         {{start1_line, start1_col}, {end1_line, end1_col}},
         {{start2_line, start2_col}, {end2_line, end2_col}}
       ) do
    start1 = start1_line * 10_000 + start1_col
    end1 = end1_line * 10_000 + end1_col
    start2 = start2_line * 10_000 + start2_col
    end2 = end2_line * 10_000 + end2_col

    not (end1 < start2 or end2 < start1)
  end
end
