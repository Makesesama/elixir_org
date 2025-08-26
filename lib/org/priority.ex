defmodule Org.Priority do
  @moduledoc """
  Enhanced priority handling for org-mode sections.

  Provides utilities for priority comparison, inheritance, sorting, and filtering.
  Org-mode uses A (highest), B (medium), C (lowest), and nil (no priority).
  """

  @type priority :: String.t() | nil
  @type comparison :: :gt | :eq | :lt

  @doc """
  Compares two priorities.

  A > B > C > nil

  ## Examples

      iex> Org.Priority.compare("A", "B")
      :gt
      
      iex> Org.Priority.compare("B", "B") 
      :eq
      
      iex> Org.Priority.compare("C", "A")
      :lt
      
      iex> Org.Priority.compare("A", nil)
      :gt
      
      iex> Org.Priority.compare(nil, nil)
      :eq
  """
  @spec compare(priority, priority) :: comparison
  def compare(priority1, priority2) do
    priority1_value = priority_to_numeric(priority1)
    priority2_value = priority_to_numeric(priority2)

    cond do
      priority1_value > priority2_value -> :gt
      priority1_value < priority2_value -> :lt
      true -> :eq
    end
  end

  @doc """
  Returns true if priority1 is higher than priority2.

  ## Examples

      iex> Org.Priority.higher?("A", "B")
      true
      
      iex> Org.Priority.higher?("B", "A")
      false
      
      iex> Org.Priority.higher?("A", nil)
      true
  """
  @spec higher?(priority, priority) :: boolean
  def higher?(priority1, priority2) do
    compare(priority1, priority2) == :gt
  end

  @doc """
  Returns true if priority1 is lower than priority2.

  ## Examples

      iex> Org.Priority.lower?("C", "A")
      true
      
      iex> Org.Priority.lower?(nil, "C")
      true
  """
  @spec lower?(priority, priority) :: boolean
  def lower?(priority1, priority2) do
    compare(priority1, priority2) == :lt
  end

  @doc """
  Returns true if priorities are equal.

  ## Examples

      iex> Org.Priority.equal?("A", "A")
      true
      
      iex> Org.Priority.equal?(nil, nil)
      true
  """
  @spec equal?(priority, priority) :: boolean
  def equal?(priority1, priority2) do
    compare(priority1, priority2) == :eq
  end

  @doc """
  Returns true if the priority is at least as high as the minimum priority.

  ## Examples

      iex> Org.Priority.at_least?("A", "B")
      true
      
      iex> Org.Priority.at_least?("B", "A")
      false
      
      iex> Org.Priority.at_least?("B", "B")
      true
  """
  @spec at_least?(priority, priority) :: boolean
  def at_least?(priority, min_priority) do
    compare(priority, min_priority) != :lt
  end

  @doc """
  Returns true if the priority is at most as high as the maximum priority.

  ## Examples

      iex> Org.Priority.at_most?("C", "B")
      true
      
      iex> Org.Priority.at_most?("A", "B")
      false
  """
  @spec at_most?(priority, priority) :: boolean
  def at_most?(priority, max_priority) do
    compare(priority, max_priority) != :gt
  end

  @doc """
  Returns true if priority is in the given range (inclusive).
  Range is from highest to lowest priority: high_priority to low_priority.

  ## Examples

      iex> Org.Priority.in_range?("B", "A", "C")
      true
      
      iex> Org.Priority.in_range?("A", "B", "C")
      false
      
      iex> Org.Priority.in_range?(nil, "B", "C")
      false
  """
  @spec in_range?(priority, priority, priority) :: boolean
  def in_range?(priority, high_priority, low_priority) do
    at_most?(priority, high_priority) && at_least?(priority, low_priority)
  end

  @doc """
  Sorts a list of priorities in descending order (A → B → C → nil).

  ## Examples

      iex> Org.Priority.sort_priorities(["C", "A", nil, "B"])
      ["A", "B", "C", nil]
  """
  @spec sort_priorities([priority]) :: [priority]
  def sort_priorities(priorities) do
    Enum.sort(priorities, fn p1, p2 -> higher?(p1, p2) end)
  end

  @doc """
  Calculates the effective priority of a section, considering inheritance.

  If the section has no priority, it inherits from its parent chain.
  Returns the first non-nil priority found in the inheritance chain.

  ## Examples

      iex> parent = %Org.Section{title: "Parent", priority: "A"}
      iex> child = %Org.Section{title: "Child", priority: nil}
      iex> Org.Priority.effective_priority(child, [parent])
      "A"
      
      iex> section = %Org.Section{title: "Section", priority: "B"}
      iex> Org.Priority.effective_priority(section, [])
      "B"
  """
  @spec effective_priority(Org.Section.t(), [Org.Section.t()]) :: priority
  def effective_priority(%Org.Section{priority: priority}, _ancestors) when priority != nil do
    priority
  end

  def effective_priority(%Org.Section{priority: nil}, ancestors) do
    ancestors
    |> Enum.find_value(fn ancestor -> ancestor.priority end)
  end

  @doc """
  Returns all valid priority levels in order from highest to lowest.
  """
  @spec all_priorities() :: [String.t()]
  def all_priorities, do: ["A", "B", "C"]

  @doc """
  Returns true if the given priority is valid.

  ## Examples

      iex> Org.Priority.valid?("A")
      true
      
      iex> Org.Priority.valid?("D")
      false
      
      iex> Org.Priority.valid?(nil)
      true
  """
  @spec valid?(priority) :: boolean
  def valid?(nil), do: true
  def valid?(priority) when priority in ["A", "B", "C"], do: true
  def valid?(_), do: false

  @doc """
  Returns the next higher priority level.

  ## Examples

      iex> Org.Priority.increase("C")
      "B"
      
      iex> Org.Priority.increase("B")
      "A"
      
      iex> Org.Priority.increase("A")
      "A"
      
      iex> Org.Priority.increase(nil)
      "C"
  """
  @spec increase(priority) :: String.t()
  def increase(nil), do: "C"
  def increase("C"), do: "B"
  def increase("B"), do: "A"
  def increase("A"), do: "A"

  @doc """
  Returns the next lower priority level.

  ## Examples

      iex> Org.Priority.decrease("A")
      "B"
      
      iex> Org.Priority.decrease("B")
      "C"
      
      iex> Org.Priority.decrease("C")
      nil
      
      iex> Org.Priority.decrease(nil)
      nil
  """
  @spec decrease(priority) :: priority
  def decrease("A"), do: "B"
  def decrease("B"), do: "C"
  def decrease("C"), do: nil
  def decrease(nil), do: nil

  # Private helper functions

  defp priority_to_numeric(nil), do: 0
  defp priority_to_numeric("C"), do: 1
  defp priority_to_numeric("B"), do: 2
  defp priority_to_numeric("A"), do: 3
  # Invalid priorities treated as no priority
  defp priority_to_numeric(_), do: 0
end
