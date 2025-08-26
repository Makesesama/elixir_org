defmodule Org.PlanningTest do
  use ExUnit.Case
  doctest Org.Writer

  describe "scheduling functions" do
    test "can schedule a task" do
      doc = Org.load_string("* TODO Task")
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon 09:00>")

      doc = Org.schedule(doc, ["Task"], timestamp)
      task = Org.section(doc, ["Task"])

      assert task.metadata[:scheduled] == timestamp
      assert task.metadata[:scheduled].date == ~D[2024-01-15]
      assert task.metadata[:scheduled].start_time == ~T[09:00:00]
    end

    test "can set deadline on a task" do
      doc = Org.load_string("* TODO Task")
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-20 Sat>")

      doc = Org.deadline(doc, ["Task"], timestamp)
      task = Org.section(doc, ["Task"])

      assert task.metadata[:deadline] == timestamp
      assert task.metadata[:deadline].date == ~D[2024-01-20]
    end

    test "can complete a task" do
      doc = Org.load_string("* TODO Task")
      completion_time = DateTime.from_naive!(~N[2024-01-18 14:30:00], "Etc/UTC")

      doc = Org.complete_task(doc, ["Task"], completion_time)
      task = Org.section(doc, ["Task"])

      assert task.todo_keyword == "DONE"
      assert task.metadata[:closed] != nil
      assert task.metadata[:closed].date == ~D[2024-01-18]
      assert task.metadata[:closed].type == :inactive
    end

    test "can unschedule a task" do
      doc =
        Org.load_string("""
        * TODO Task
          SCHEDULED: <2024-01-15 Mon>
        """)

      task = Org.section(doc, ["Task"])
      assert task.metadata[:scheduled] != nil

      doc = Org.unschedule(doc, ["Task"])
      task = Org.section(doc, ["Task"])

      assert task.metadata[:scheduled] == nil
    end

    test "can add scheduled task in one call" do
      doc = Org.load_string("* Parent")
      {:ok, scheduled} = Org.Timestamp.parse("<2024-01-15 Mon 09:00>")
      {:ok, deadline} = Org.Timestamp.parse("<2024-01-20 Sat>")

      doc = Org.add_scheduled_task(doc, ["Parent"], "Important Task", "TODO", "A", scheduled, deadline)
      task = Org.section(doc, ["Parent", "Important Task"])

      assert task.title == "Important Task"
      assert task.todo_keyword == "TODO"
      assert task.priority == "A"
      assert task.metadata[:scheduled].date == ~D[2024-01-15]
      assert task.metadata[:deadline].date == ~D[2024-01-20]
    end
  end

  describe "planning metadata extraction" do
    test "can find scheduled items" do
      doc =
        Org.load_string("""
        * TODO Task 1
          SCHEDULED: <2024-01-15 Mon>
        * Regular Task
        * TODO Task 2
          SCHEDULED: <2024-01-20 Sat>
        """)

      scheduled = Org.scheduled_items(doc)

      assert length(scheduled) == 2
      titles = Enum.map(scheduled, & &1.title)
      assert "Task 1" in titles
      assert "Task 2" in titles
    end

    test "can find deadline items" do
      doc =
        Org.load_string("""
        * TODO Task 1
          DEADLINE: <2024-01-15 Mon>
        * Regular Task
        * TODO Task 2
          DEADLINE: <2024-01-20 Sat>
        """)

      deadlines = Org.deadline_items(doc)

      assert length(deadlines) == 2
      titles = Enum.map(deadlines, & &1.title)
      assert "Task 1" in titles
      assert "Task 2" in titles
    end

    test "can find closed items" do
      doc =
        Org.load_string("""
        * DONE Task 1
          CLOSED: [2024-01-15 Mon]
        * TODO Task 2
        * DONE Task 3
          CLOSED: [2024-01-20 Sat]
        """)

      closed = Org.closed_items(doc)

      assert length(closed) == 2
      titles = Enum.map(closed, & &1.title)
      assert "Task 1" in titles
      assert "Task 3" in titles
    end

    test "can find agenda items for specific date" do
      doc =
        Org.load_string("""
        * TODO Task 1
          SCHEDULED: <2024-01-15 Mon>
        * TODO Task 2
          SCHEDULED: <2024-01-16 Tue>
        * TODO Task 3
          SCHEDULED: <2024-01-15 Mon>
        """)

      agenda = Org.agenda_items(doc, ~D[2024-01-15])

      assert length(agenda) == 2
      titles = Enum.map(agenda, & &1.title)
      assert "Task 1" in titles
      assert "Task 3" in titles
      refute "Task 2" in titles
    end

    test "can find overdue items" do
      doc =
        Org.load_string("""
        * TODO Task 1
          DEADLINE: <2024-01-10 Wed>
        * DONE Task 2
          DEADLINE: <2024-01-12 Fri>
        * TODO Task 3
          DEADLINE: <2024-01-20 Sat>
        """)

      overdue = Org.overdue_items(doc, ~D[2024-01-15])

      assert length(overdue) == 1
      task = hd(overdue)
      assert task.title == "Task 1"
      assert task.todo_keyword == "TODO"
    end
  end

  describe "serialization with planning metadata" do
    test "serializes scheduled and deadline timestamps" do
      doc = Org.load_string("* TODO Task")
      {:ok, scheduled} = Org.Timestamp.parse("<2024-01-15 Mon 09:00>")
      {:ok, deadline} = Org.Timestamp.parse("<2024-01-20 Sat>")

      doc =
        doc
        |> Org.schedule(["Task"], scheduled)
        |> Org.deadline(["Task"], deadline)

      org_text = Org.to_org_string(doc)

      assert String.contains?(org_text, "SCHEDULED: <2024-01-15 Mon 09:00>")
      assert String.contains?(org_text, "DEADLINE: <2024-01-20 Sat>")
    end

    test "round trip preserves planning metadata" do
      original_text = """
      * TODO Important Task
        SCHEDULED: <2024-01-15 Mon 09:00>
        DEADLINE: <2024-01-20 Sat>
        This is the task content.
      """

      doc = Org.load_string(original_text)
      serialized = Org.to_org_string(doc)
      reparsed = Org.load_string(serialized)

      task = Org.section(reparsed, ["Important Task"])
      assert task.metadata[:scheduled].date == ~D[2024-01-15]
      assert task.metadata[:deadline].date == ~D[2024-01-20]
      assert task.todo_keyword == "TODO"
    end
  end

  describe "planning metadata updates" do
    test "can update multiple planning fields at once" do
      doc = Org.load_string("* TODO Task")
      {:ok, scheduled} = Org.Timestamp.parse("<2024-01-15 Mon>")
      {:ok, deadline} = Org.Timestamp.parse("<2024-01-20 Sat>")

      planning = %{scheduled: scheduled, deadline: deadline}
      doc = Org.Writer.update_planning(doc, ["Task"], planning)

      task = Org.section(doc, ["Task"])
      assert task.metadata[:scheduled].date == ~D[2024-01-15]
      assert task.metadata[:deadline].date == ~D[2024-01-20]
    end

    test "partial updates preserve existing metadata" do
      doc =
        Org.load_string("""
        * TODO Task
          SCHEDULED: <2024-01-15 Mon>
          DEADLINE: <2024-01-20 Sat>
        """)

      {:ok, new_deadline} = Org.Timestamp.parse("<2024-01-25 Thu>")
      doc = Org.deadline(doc, ["Task"], new_deadline)

      task = Org.section(doc, ["Task"])
      # Preserved
      assert task.metadata[:scheduled].date == ~D[2024-01-15]
      # Updated
      assert task.metadata[:deadline].date == ~D[2024-01-25]
    end
  end

  describe "complete task workflow" do
    test "completing task sets DONE and CLOSED" do
      doc =
        Org.load_string("""
        * TODO Important Project
          SCHEDULED: <2024-01-15 Mon>
          DEADLINE: <2024-01-20 Sat>
        """)

      completion_time = DateTime.from_naive!(~N[2024-01-18 14:30:00], "Etc/UTC")
      doc = Org.complete_task(doc, ["Important Project"], completion_time)

      task = Org.section(doc, ["Important Project"])
      assert task.todo_keyword == "DONE"
      assert task.metadata[:closed].date == ~D[2024-01-18]
      assert task.metadata[:closed].type == :inactive
      # Original scheduling preserved
      assert task.metadata[:scheduled].date == ~D[2024-01-15]
      assert task.metadata[:deadline].date == ~D[2024-01-20]
    end
  end

  describe "nested section planning" do
    test "can schedule nested tasks" do
      doc =
        Org.load_string("""
        * Project
        ** TODO Subtask 1
        ** TODO Subtask 2
        """)

      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon 10:00>")
      doc = Org.schedule(doc, ["Project", "Subtask 1"], timestamp)

      subtask = Org.section(doc, ["Project", "Subtask 1"])
      assert subtask.metadata[:scheduled].date == ~D[2024-01-15]
      assert subtask.metadata[:scheduled].start_time == ~T[10:00:00]

      # Other subtask unaffected
      subtask2 = Org.section(doc, ["Project", "Subtask 2"])
      assert subtask2.metadata[:scheduled] == nil
    end
  end
end
