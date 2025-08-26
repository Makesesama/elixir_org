defmodule Org.PriorityTest do
  use ExUnit.Case
  doctest Org.Priority

  describe "priority comparison" do
    test "compare returns correct ordering" do
      assert Org.Priority.compare("A", "B") == :gt
      assert Org.Priority.compare("B", "A") == :lt
      assert Org.Priority.compare("A", "A") == :eq
      assert Org.Priority.compare("B", "C") == :gt
      assert Org.Priority.compare("C", "B") == :lt
      assert Org.Priority.compare("A", nil) == :gt
      assert Org.Priority.compare(nil, "C") == :lt
      assert Org.Priority.compare(nil, nil) == :eq
    end

    test "higher? works correctly" do
      assert Org.Priority.higher?("A", "B") == true
      assert Org.Priority.higher?("B", "C") == true
      assert Org.Priority.higher?("A", nil) == true
      assert Org.Priority.higher?("B", "A") == false
      assert Org.Priority.higher?(nil, "C") == false
      assert Org.Priority.higher?("A", "A") == false
    end

    test "lower? works correctly" do
      assert Org.Priority.lower?("B", "A") == true
      assert Org.Priority.lower?("C", "B") == true
      assert Org.Priority.lower?(nil, "C") == true
      assert Org.Priority.lower?("A", "B") == false
      assert Org.Priority.lower?("C", nil) == false
      assert Org.Priority.lower?("A", "A") == false
    end

    test "equal? works correctly" do
      assert Org.Priority.equal?("A", "A") == true
      assert Org.Priority.equal?("B", "B") == true
      assert Org.Priority.equal?("C", "C") == true
      assert Org.Priority.equal?(nil, nil) == true
      assert Org.Priority.equal?("A", "B") == false
      assert Org.Priority.equal?("A", nil) == false
    end
  end

  describe "priority range queries" do
    test "at_least? works correctly" do
      assert Org.Priority.at_least?("A", "A") == true
      assert Org.Priority.at_least?("A", "B") == true
      assert Org.Priority.at_least?("B", "C") == true
      assert Org.Priority.at_least?("B", "A") == false
      assert Org.Priority.at_least?("C", "A") == false
      assert Org.Priority.at_least?(nil, "C") == false
      assert Org.Priority.at_least?("A", nil) == true
    end

    test "at_most? works correctly" do
      assert Org.Priority.at_most?("A", "A") == true
      assert Org.Priority.at_most?("B", "A") == true
      assert Org.Priority.at_most?("C", "B") == true
      assert Org.Priority.at_most?("A", "B") == false
      assert Org.Priority.at_most?("A", "C") == false
      assert Org.Priority.at_most?("C", nil) == false
      assert Org.Priority.at_most?(nil, "A") == true
    end

    test "in_range? works correctly" do
      # Range from A (high) to C (low)
      assert Org.Priority.in_range?("B", "A", "C") == true
      assert Org.Priority.in_range?("A", "A", "C") == true
      assert Org.Priority.in_range?("C", "A", "C") == true
      assert Org.Priority.in_range?("A", "B", "C") == false
      assert Org.Priority.in_range?(nil, "B", "C") == false
      # Invalid range: high priority should be higher than low priority
      assert Org.Priority.in_range?("B", "C", "A") == false
    end
  end

  describe "priority sorting" do
    test "sort_priorities orders correctly" do
      assert Org.Priority.sort_priorities(["C", "A", nil, "B"]) == ["A", "B", "C", nil]
      assert Org.Priority.sort_priorities([nil, nil, "A"]) == ["A", nil, nil]
      assert Org.Priority.sort_priorities([]) == []
      assert Org.Priority.sort_priorities(["B", "B", "A"]) == ["A", "B", "B"]
    end
  end

  describe "priority utilities" do
    test "all_priorities returns valid priorities" do
      assert Org.Priority.all_priorities() == ["A", "B", "C"]
    end

    test "valid? checks priority validity" do
      assert Org.Priority.valid?("A") == true
      assert Org.Priority.valid?("B") == true
      assert Org.Priority.valid?("C") == true
      assert Org.Priority.valid?(nil) == true
      assert Org.Priority.valid?("D") == false
      assert Org.Priority.valid?("1") == false
      assert Org.Priority.valid?("") == false
    end

    test "increase raises priority level" do
      assert Org.Priority.increase(nil) == "C"
      assert Org.Priority.increase("C") == "B"
      assert Org.Priority.increase("B") == "A"
      # Already at highest
      assert Org.Priority.increase("A") == "A"
    end

    test "decrease lowers priority level" do
      assert Org.Priority.decrease("A") == "B"
      assert Org.Priority.decrease("B") == "C"
      assert Org.Priority.decrease("C") == nil
      # Already at lowest
      assert Org.Priority.decrease(nil) == nil
    end
  end

  describe "effective priority calculation" do
    test "returns section priority when it exists" do
      parent = %Org.Section{title: "Parent", priority: "A"}
      child = %Org.Section{title: "Child", priority: "B"}

      assert Org.Priority.effective_priority(child, [parent]) == "B"
    end

    test "inherits from ancestors when section has no priority" do
      parent = %Org.Section{title: "Parent", priority: "A"}
      child = %Org.Section{title: "Child", priority: nil}

      assert Org.Priority.effective_priority(child, [parent]) == "A"
    end

    test "returns nil when no priority in chain" do
      parent = %Org.Section{title: "Parent", priority: nil}
      child = %Org.Section{title: "Child", priority: nil}

      assert Org.Priority.effective_priority(child, [parent]) == nil
    end

    test "finds first non-nil priority in ancestor chain" do
      grandparent = %Org.Section{title: "Grandparent", priority: "A"}
      parent = %Org.Section{title: "Parent", priority: nil}
      child = %Org.Section{title: "Child", priority: nil}

      assert Org.Priority.effective_priority(child, [grandparent, parent]) == "A"
    end
  end
end
