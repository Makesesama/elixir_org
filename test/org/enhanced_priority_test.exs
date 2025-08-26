defmodule Org.EnhancedPriorityTest do
  use ExUnit.Case
  doctest Org

  describe "sections with minimum priority" do
    test "filters sections by minimum priority" do
      doc =
        Org.load_string("""
        * TODO [#A] High priority task
        * TODO [#B] Medium priority task
        * TODO [#C] Low priority task
        * TODO Regular task
        """)

      # Get sections with at least priority B
      important = Org.sections_with_min_priority(doc, "B")
      titles = Enum.map(important, & &1.title)

      assert "High priority task" in titles
      assert "Medium priority task" in titles
      refute "Low priority task" in titles
      refute "Regular task" in titles
      assert length(important) == 2
    end

    test "works with priority A (highest only)" do
      doc =
        Org.load_string("""
        * TODO [#A] Critical task
        * TODO [#B] Important task
        * TODO [#C] Minor task
        """)

      critical = Org.sections_with_min_priority(doc, "A")
      assert length(critical) == 1
      assert hd(critical).title == "Critical task"
    end

    test "returns empty list when no sections meet criteria" do
      doc =
        Org.load_string("""
        * TODO [#C] Low task
        * TODO Regular task
        """)

      high_priority = Org.sections_with_min_priority(doc, "A")
      assert high_priority == []
    end
  end

  describe "sections with priority range" do
    test "filters sections within priority range" do
      doc =
        Org.load_string("""
        * TODO [#A] High priority task
        * TODO [#B] Medium priority task
        * TODO [#C] Low priority task
        * TODO Regular task
        """)

      # Get sections with priority B to C
      mid_range = Org.sections_with_priority_range(doc, "B", "C")
      titles = Enum.map(mid_range, & &1.title)

      refute "High priority task" in titles
      assert "Medium priority task" in titles
      assert "Low priority task" in titles
      refute "Regular task" in titles
      assert length(mid_range) == 2
    end

    test "handles single priority range (A to A)" do
      doc =
        Org.load_string("""
        * TODO [#A] Critical task
        * TODO [#B] Important task
        """)

      only_a = Org.sections_with_priority_range(doc, "A", "A")
      assert length(only_a) == 1
      assert hd(only_a).title == "Critical task"
    end

    test "returns empty list for invalid range" do
      doc =
        Org.load_string("""
        * TODO [#B] Task
        """)

      # Invalid range (C to A)
      invalid_range = Org.sections_with_priority_range(doc, "C", "A")
      assert invalid_range == []
    end
  end

  describe "sections sorted by priority" do
    test "sorts sections in priority order A > B > C > nil" do
      doc =
        Org.load_string("""
        * TODO [#C] Low task
        * TODO Regular task
        * TODO [#A] High task
        * TODO [#B] Medium task
        """)

      sorted = Org.sections_sorted_by_priority(doc)
      titles = Enum.map(sorted, & &1.title)

      assert titles == ["High task", "Medium task", "Low task", "Regular task"]
    end

    test "handles multiple sections with same priority" do
      doc =
        Org.load_string("""
        * TODO [#A] First A task
        * TODO [#A] Second A task
        * TODO [#B] B task
        """)

      sorted = Org.sections_sorted_by_priority(doc)
      priorities = Enum.map(sorted, & &1.priority)

      # First two should be priority A, last should be B
      assert Enum.take(priorities, 2) == ["A", "A"]
      assert List.last(priorities) == "B"
    end

    test "works with nested sections" do
      doc =
        Org.load_string("""
        * TODO [#B] Parent
        ** TODO [#A] Child
        * TODO [#C] Another parent
        """)

      sorted = Org.sections_sorted_by_priority(doc)
      titles = Enum.map(sorted, & &1.title)

      # Highest priority (A)
      assert hd(titles) == "Child"
      assert "Parent" in titles
      assert "Another parent" in titles
    end
  end

  describe "high priority sections" do
    test "extracts only priority A sections" do
      doc =
        Org.load_string("""
        * TODO [#A] Critical task
        * TODO [#A] Another critical task  
        * TODO [#B] Important task
        * TODO [#C] Minor task
        """)

      high = Org.high_priority_sections(doc)
      titles = Enum.map(high, & &1.title)

      assert "Critical task" in titles
      assert "Another critical task" in titles
      refute "Important task" in titles
      refute "Minor task" in titles
      assert length(high) == 2
    end

    test "returns empty list when no A priority sections exist" do
      doc =
        Org.load_string("""
        * TODO [#B] Task
        * TODO [#C] Another task
        """)

      high = Org.high_priority_sections(doc)
      assert high == []
    end
  end

  describe "effective priority" do
    test "returns section priority when it exists" do
      doc =
        Org.load_string("""
        * TODO [#A] Parent
        ** TODO [#B] Child with own priority
        """)

      child_priority = Org.effective_priority(doc, ["Parent", "Child with own priority"])
      assert child_priority == "B"
    end

    test "inherits priority from parent when section has none" do
      doc =
        Org.load_string("""
        * TODO [#A] Parent task
        ** TODO Child task
        *** TODO Grandchild task
        """)

      child_priority = Org.effective_priority(doc, ["Parent task", "Child task"])
      grandchild_priority = Org.effective_priority(doc, ["Parent task", "Child task", "Grandchild task"])

      assert child_priority == "A"
      assert grandchild_priority == "A"
    end

    test "returns nil when no priority in inheritance chain" do
      doc =
        Org.load_string("""
        * TODO Parent
        ** TODO Child
        """)

      child_priority = Org.effective_priority(doc, ["Parent", "Child"])
      assert child_priority == nil
    end

    test "finds priority from closest ancestor" do
      doc =
        Org.load_string("""
        * TODO [#A] Grandparent
        ** TODO Parent (no priority)
        *** TODO [#B] Child with priority
        **** TODO Grandchild
        """)

      grandchild_priority =
        Org.effective_priority(doc, ["Grandparent", "Parent (no priority)", "Child with priority", "Grandchild"])

      # Inherits from immediate parent, not grandparent
      assert grandchild_priority == "B"
    end

    test "skips nil priorities in chain" do
      doc =
        Org.load_string("""
        * TODO [#A] Great grandparent
        ** TODO Grandparent (no priority)
        *** TODO Parent (no priority)
        **** TODO Child (no priority)
        """)

      child_priority =
        Org.effective_priority(doc, [
          "Great grandparent",
          "Grandparent (no priority)",
          "Parent (no priority)",
          "Child (no priority)"
        ])

      # Inherits from great grandparent
      assert child_priority == "A"
    end
  end

  describe "sections with effective priority" do
    test "finds sections with direct or inherited priority" do
      doc =
        Org.load_string("""
        * TODO [#A] Parent with priority
        ** TODO Child inherits priority
        *** TODO Grandchild also inherits
        * TODO [#B] Another parent
        ** TODO Another child inherits
        * TODO Regular parent
        ** TODO Regular child
        """)

      effective = Org.sections_with_effective_priority(doc)
      titles = Enum.map(effective, & &1.title)

      # Should include sections with direct priority and those that inherit
      assert "Parent with priority" in titles
      assert "Child inherits priority" in titles
      assert "Grandchild also inherits" in titles
      assert "Another parent" in titles
      assert "Another child inherits" in titles

      # Should not include sections with no effective priority
      refute "Regular parent" in titles
      refute "Regular child" in titles

      assert length(effective) == 5
    end

    test "handles mixed scenarios correctly" do
      doc =
        Org.load_string("""
        * TODO [#A] Priority parent
        ** TODO [#B] Priority child (overrides parent)
        *** TODO Grandchild (inherits from child)
        * TODO Regular parent
        ** TODO Regular child
        """)

      effective = Org.sections_with_effective_priority(doc)
      # Parent, child, and grandchild
      assert length(effective) == 3

      # Check that grandchild inherits B, not A
      grandchild_priority =
        Org.effective_priority(doc, [
          "Priority parent",
          "Priority child (overrides parent)",
          "Grandchild (inherits from child)"
        ])

      assert grandchild_priority == "B"
    end

    test "returns empty list when no sections have effective priority" do
      doc =
        Org.load_string("""
        * TODO Regular parent
        ** TODO Regular child
        *** TODO Regular grandchild
        """)

      effective = Org.sections_with_effective_priority(doc)
      assert effective == []
    end
  end

  describe "integration with existing functionality" do
    test "enhanced priority works with TODO sections" do
      doc =
        Org.load_string("""
        * TODO [#A] High priority TODO
        * DONE [#B] Completed task
        * TODO [#C] Low priority TODO
        * TODO Regular TODO
        """)

      # Get high priority TODO sections
      high_todos = Org.high_priority_sections(doc)
      high_todo_titles = Enum.map(high_todos, & &1.title)

      assert "High priority TODO" in high_todo_titles
      # DONE, not TODO
      refute "Completed task" in high_todo_titles
      assert length(high_todos) == 1
    end

    test "priority sorting works with different TODO states" do
      doc =
        Org.load_string("""
        * DONE [#C] Completed low priority
        * TODO [#A] Active high priority
        * DONE [#A] Completed high priority
        * TODO [#B] Active medium priority
        """)

      sorted = Org.sections_sorted_by_priority(doc)
      titles = Enum.map(sorted, & &1.title)

      # Should sort by priority regardless of TODO state
      assert Enum.take(titles, 2) |> Enum.sort() == ["Active high priority", "Completed high priority"]
      assert Enum.at(titles, 2) == "Active medium priority"
      assert Enum.at(titles, 3) == "Completed low priority"
    end

    test "effective priority works with complex hierarchies" do
      doc =
        Org.load_string("""
        * TODO [#A] Project
        ** TODO [#B] Feature
        *** TODO Implementation
        **** TODO Unit tests
        ** TODO Documentation
        *** TODO [#C] API docs
        """)

      # Check effective priorities
      impl_priority = Org.effective_priority(doc, ["Project", "Feature", "Implementation"])
      tests_priority = Org.effective_priority(doc, ["Project", "Feature", "Implementation", "Unit tests"])
      docs_priority = Org.effective_priority(doc, ["Project", "Documentation"])
      api_docs_priority = Org.effective_priority(doc, ["Project", "Documentation", "API docs"])

      # Inherits from Feature
      assert impl_priority == "B"
      # Inherits through Implementation from Feature
      assert tests_priority == "B"
      # Inherits from Project
      assert docs_priority == "A"
      # Has its own priority
      assert api_docs_priority == "C"
    end
  end
end
