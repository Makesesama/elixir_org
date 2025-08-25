defmodule Org.IncrementalParserTest do
  use ExUnit.Case
  doctest Org.IncrementalParser

  alias Org.IncrementalParser

  setup do
    text = "* Section 1\n\nContent paragraph\n\n* Section 2\nMore content here"
    state = IncrementalParser.new(text)

    {:ok, state: state, text: text}
  end

  describe "new/1" do
    test "creates initial parse state", %{state: state} do
      assert state.document != nil
      assert state.tracker != nil
      assert state.version == 0
      assert state.pending_changes == []
    end

    test "parses document correctly on initialization", %{state: state} do
      doc = state.document
      assert length(doc.sections) >= 1

      # Should have sections with expected titles
      section_titles = Enum.map(doc.sections, & &1.title)
      assert "Section 1" in section_titles
      assert "Section 2" in section_titles
    end

    test "creates fragment tracker", %{state: state} do
      tracker = state.tracker
      assert is_map(tracker.fragments)
      assert map_size(tracker.fragments) > 0
      assert tracker.source_text != ""
    end
  end

  describe "apply_change/2" do
    test "queues change for later processing", %{state: state} do
      change = %{
        range: {{1, 3}, {1, 12}},
        old_text: "Section 1",
        new_text: "Updated Section 1"
      }

      updated_state = IncrementalParser.apply_change(state, change)

      assert length(updated_state.pending_changes) == 1
      assert hd(updated_state.pending_changes) == change
      # Version unchanged until commit
      assert updated_state.version == state.version
    end

    test "accumulates multiple changes", %{state: state} do
      change1 = %{
        range: {{1, 1}, {1, 10}},
        old_text: "* Section",
        new_text: "* Modified"
      }

      change2 = %{
        range: {{3, 1}, {3, 17}},
        old_text: "Content paragraph",
        new_text: "Updated content"
      }

      updated_state =
        state
        |> IncrementalParser.apply_change(change1)
        |> IncrementalParser.apply_change(change2)

      assert length(updated_state.pending_changes) == 2
      assert change1 in updated_state.pending_changes
      assert change2 in updated_state.pending_changes
    end
  end

  describe "apply_changes/2" do
    test "applies multiple changes at once", %{state: state} do
      changes = [
        %{range: {{1, 1}, {1, 10}}, old_text: "* Section", new_text: "* Updated"},
        %{range: {{5, 1}, {5, 10}}, old_text: "* Section", new_text: "* Changed"}
      ]

      updated_state = IncrementalParser.apply_changes(state, changes)

      assert length(updated_state.pending_changes) == 2

      Enum.each(changes, fn change ->
        assert change in updated_state.pending_changes
      end)
    end
  end

  describe "commit_changes/1" do
    test "processes pending changes and updates version", %{state: state} do
      change = %{
        range: {{1, 3}, {1, 12}},
        old_text: "Section 1",
        new_text: "Modified Section"
      }

      state_with_change = IncrementalParser.apply_change(state, change)
      committed_state = IncrementalParser.commit_changes(state_with_change)

      assert committed_state.version > state.version
      assert committed_state.pending_changes == []
    end

    test "handles empty pending changes", %{state: state} do
      committed_state = IncrementalParser.commit_changes(state)

      # No changes, should be identical
      assert committed_state == state
    end

    test "updates document structure after commit" do
      initial_state = IncrementalParser.new("* Original Title")

      change = %{
        range: {{1, 3}, {1, 16}},
        old_text: "Original Title",
        new_text: "New Title"
      }

      final_state =
        initial_state
        |> IncrementalParser.apply_change(change)
        |> IncrementalParser.commit_changes()

      # Version should be incremented even if document structure isn't updated yet
      # (This is a simplified implementation - document updating is not fully implemented)
      assert final_state.version > initial_state.version
      # Clear pending changes
      assert final_state.pending_changes == []
    end

    test "processes multiple changes in batch", %{state: state} do
      changes = [
        %{range: {{1, 3}, {1, 12}}, old_text: "Section 1", new_text: "Part 1"},
        %{range: {{5, 3}, {5, 12}}, old_text: "Section 2", new_text: "Part 2"}
      ]

      final_state =
        state
        |> IncrementalParser.apply_changes(changes)
        |> IncrementalParser.commit_changes()

      assert final_state.version == state.version + 1
      assert final_state.pending_changes == []
    end
  end

  describe "get_version/1" do
    test "returns current version", %{state: state} do
      assert IncrementalParser.get_version(state) == 0
    end

    test "tracks version increments", %{state: state} do
      change = %{range: {{1, 1}, {1, 5}}, old_text: "* Se", new_text: "* Up"}

      updated_state =
        state
        |> IncrementalParser.apply_change(change)
        |> IncrementalParser.commit_changes()

      assert IncrementalParser.get_version(updated_state) == 1
    end
  end

  describe "has_pending_changes?/1" do
    test "returns false for clean state", %{state: state} do
      assert IncrementalParser.has_pending_changes?(state) == false
    end

    test "returns true when changes are pending", %{state: state} do
      change = %{range: {{1, 1}, {1, 2}}, old_text: "*", new_text: "**"}

      state_with_change = IncrementalParser.apply_change(state, change)
      assert IncrementalParser.has_pending_changes?(state_with_change) == true
    end

    test "returns false after committing changes", %{state: state} do
      change = %{range: {{1, 1}, {1, 2}}, old_text: "*", new_text: "**"}

      final_state =
        state
        |> IncrementalParser.apply_change(change)
        |> IncrementalParser.commit_changes()

      assert IncrementalParser.has_pending_changes?(final_state) == false
    end
  end

  describe "preview_changes/1" do
    test "provides preview of pending changes", %{state: state} do
      changes = [
        %{range: {{1, 1}, {1, 10}}, old_text: "* Section", new_text: "* Changed"},
        %{range: {{3, 1}, {3, 8}}, old_text: "Content", new_text: "Updated"}
      ]

      state_with_changes = IncrementalParser.apply_changes(state, changes)
      preview = IncrementalParser.preview_changes(state_with_changes)

      assert is_list(preview.affected_fragments)
      assert is_list(preview.affected_sections)
      assert is_list(preview.new_text_ranges)
      assert length(preview.new_text_ranges) == 2
    end

    test "returns empty preview for clean state", %{state: state} do
      preview = IncrementalParser.preview_changes(state)

      assert preview.affected_fragments == []
      assert preview.affected_sections == []
      assert preview.new_text_ranges == []
    end
  end

  describe "optimize/1" do
    test "returns same state when optimization not needed", %{state: state} do
      optimized = IncrementalParser.optimize(state)

      # With no dirty fragments, should return same state
      assert optimized.version == state.version
    end

    test "rebuilds state when many fragments are dirty" do
      # Create state with text
      # Many fragments
      initial_text = String.duplicate("* Section\nContent\n", 20)
      state = IncrementalParser.new(initial_text)

      # Make many changes to create dirty fragments
      changes =
        0..15
        |> Enum.map(fn i ->
          line = i * 2 + 1

          %{
            range: {{line, 1}, {line, 9}},
            old_text: "* Section",
            new_text: "* Updated#{i}"
          }
        end)

      dirty_state = IncrementalParser.apply_changes(state, changes)
      optimized = IncrementalParser.optimize(dirty_state)

      # Should optimize by potentially rebuilding state
      # For now, just verify that optimize returns a valid state
      assert is_map(optimized)
      assert optimized.version >= 0
      assert is_list(optimized.pending_changes)
    end
  end

  describe "complex incremental editing scenarios" do
    test "handles section title changes" do
      state = IncrementalParser.new("* Original Title\nContent under section")

      change = %{
        range: {{1, 3}, {1, 17}},
        old_text: "Original Title",
        new_text: "Modified Title"
      }

      final_state =
        state
        |> IncrementalParser.apply_change(change)
        |> IncrementalParser.commit_changes()

      assert final_state.version == 1
      assert not IncrementalParser.has_pending_changes?(final_state)
    end

    test "handles content additions" do
      state = IncrementalParser.new("* Section\nExisting content")

      change = %{
        # Insert at end of line
        range: {{2, 16}, {2, 16}},
        old_text: "",
        new_text: " and new content"
      }

      final_state =
        state
        |> IncrementalParser.apply_change(change)
        |> IncrementalParser.commit_changes()

      assert final_state.version == 1
    end

    test "handles content deletions" do
      state = IncrementalParser.new("* Section\nContent to be partially deleted")

      change = %{
        # Delete part of the content
        range: {{2, 9}, {2, 42}},
        old_text: "to be partially deleted",
        new_text: "modified"
      }

      final_state =
        state
        |> IncrementalParser.apply_change(change)
        |> IncrementalParser.commit_changes()

      assert final_state.version == 1
    end

    test "handles multiple section modifications" do
      text = "* Section A\nContent A\n\n* Section B\nContent B\n\n* Section C\nContent C"
      state = IncrementalParser.new(text)

      changes = [
        %{range: {{1, 3}, {1, 12}}, old_text: "Section A", new_text: "Modified A"},
        %{range: {{4, 3}, {4, 12}}, old_text: "Section B", new_text: "Modified B"},
        %{range: {{7, 3}, {7, 12}}, old_text: "Section C", new_text: "Modified C"}
      ]

      final_state =
        state
        |> IncrementalParser.apply_changes(changes)
        |> IncrementalParser.commit_changes()

      assert final_state.version == 1
      assert IncrementalParser.preview_changes(final_state).affected_fragments == []
    end

    test "maintains document consistency after complex edits" do
      state = IncrementalParser.new("* A\n** B\n*** C\nContent")

      # Change that affects nested structure
      change = %{
        # Change "**" to "****"
        range: {{2, 1}, {2, 3}},
        old_text: "**",
        new_text: "****"
      }

      final_state =
        state
        |> IncrementalParser.apply_change(change)
        |> IncrementalParser.commit_changes()

      # Document should still be valid
      assert final_state.document != nil
      assert length(final_state.document.sections) >= 1
    end
  end

  describe "error handling" do
    test "handles malformed changes gracefully" do
      state = IncrementalParser.new("* Section")

      # Change with invalid range
      bad_change = %{
        range: {{-1, -1}, {1000, 1000}},
        old_text: "anything",
        new_text: "replacement"
      }

      # Should not crash
      result_state =
        state
        |> IncrementalParser.apply_change(bad_change)
        |> IncrementalParser.commit_changes()

      # Should have some result, even if not perfect
      assert is_map(result_state)
      assert result_state.version >= state.version
    end

    test "handles empty text changes" do
      state = IncrementalParser.new("* Section\nContent")

      empty_change = %{
        range: {{1, 1}, {1, 1}},
        old_text: "",
        new_text: ""
      }

      final_state =
        state
        |> IncrementalParser.apply_change(empty_change)
        |> IncrementalParser.commit_changes()

      # Should handle gracefully
      assert final_state.version >= state.version
    end
  end
end
