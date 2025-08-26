defmodule Org.RepeaterTest do
  use ExUnit.Case
  doctest Org.Timestamp

  describe "repeater calculation" do
    test "calculates next occurrence for daily repeater" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1d>")
      next = Org.Timestamp.next_occurrence(timestamp)

      assert next.date == ~D[2024-01-16]
      assert next.day_name == "Tue"
      assert next.repeater == %{count: 1, unit: :day}
    end

    test "calculates next occurrence for weekly repeater" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1w>")
      next = Org.Timestamp.next_occurrence(timestamp)

      assert next.date == ~D[2024-01-22]
      assert next.day_name == "Mon"
      assert next.repeater == %{count: 1, unit: :week}
    end

    test "calculates next occurrence for monthly repeater" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1m>")
      next = Org.Timestamp.next_occurrence(timestamp)

      assert next.date == ~D[2024-02-15]
      assert next.day_name == "Thu"
      assert next.repeater == %{count: 1, unit: :month}
    end

    test "calculates next occurrence for yearly repeater" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1y>")
      next = Org.Timestamp.next_occurrence(timestamp)

      assert next.date == ~D[2025-01-15]
      assert next.day_name == "Wed"
      assert next.repeater == %{count: 1, unit: :year}
    end

    test "handles leap year edge case" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-02-29 Thu +1y>")
      next = Org.Timestamp.next_occurrence(timestamp)

      # 2025 is not a leap year, so Feb 29 -> Feb 28
      assert next.date == ~D[2025-02-28]
      assert next.day_name == "Fri"
    end

    test "handles month overflow edge case" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-31 Wed +1m>")
      next = Org.Timestamp.next_occurrence(timestamp)

      # Jan 31 + 1 month = Feb 29 (2024 is leap year)
      assert next.date == ~D[2024-02-29]
      assert next.day_name == "Thu"
    end

    test "preserves time information" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon 09:30-11:00 +1d>")
      next = Org.Timestamp.next_occurrence(timestamp)

      assert next.date == ~D[2024-01-16]
      assert next.start_time == ~T[09:30:00]
      assert next.end_time == ~T[11:00:00]
    end

    test "returns nil for non-repeating timestamp" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon>")
      next = Org.Timestamp.next_occurrence(timestamp)

      assert next == nil
    end
  end

  describe "next occurrence from reference date" do
    test "calculates next occurrence after reference date" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1w>")
      next = Org.Timestamp.next_occurrence_from(timestamp, ~D[2024-01-20])

      assert next.date == ~D[2024-01-22]
    end

    test "returns original date if it's after reference" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1w>")
      next = Org.Timestamp.next_occurrence_from(timestamp, ~D[2024-01-10])

      assert next.date == ~D[2024-01-15]
    end

    test "calculates multiple intervals when needed" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-01 Mon +1w>")
      next = Org.Timestamp.next_occurrence_from(timestamp, ~D[2024-01-30])

      # Should be 2024-02-05 (5 weeks after original)
      assert next.date == ~D[2024-02-05]
    end
  end

  describe "occurrences in range" do
    test "generates all occurrences within date range" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1w>")
      occurrences = Org.Timestamp.occurrences_in_range(timestamp, ~D[2024-01-10], ~D[2024-02-05])

      dates = Enum.map(occurrences, & &1.date)
      assert ~D[2024-01-15] in dates
      assert ~D[2024-01-22] in dates
      assert ~D[2024-01-29] in dates
      assert ~D[2024-02-05] in dates
      assert length(occurrences) == 4
    end

    test "starts from first occurrence after start date" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-01 Mon +1w>")
      occurrences = Org.Timestamp.occurrences_in_range(timestamp, ~D[2024-01-10], ~D[2024-01-25])

      dates = Enum.map(occurrences, & &1.date)
      # First Monday after Jan 10
      assert ~D[2024-01-15] in dates
      assert ~D[2024-01-22] in dates
      assert length(occurrences) == 2
    end

    test "returns empty list for non-repeating timestamp" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon>")
      occurrences = Org.Timestamp.occurrences_in_range(timestamp, ~D[2024-01-10], ~D[2024-02-05])

      assert occurrences == []
    end

    test "includes original date if it's in range" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1w>")
      occurrences = Org.Timestamp.occurrences_in_range(timestamp, ~D[2024-01-15], ~D[2024-01-22])

      dates = Enum.map(occurrences, & &1.date)
      assert ~D[2024-01-15] in dates
      assert ~D[2024-01-22] in dates
      assert length(occurrences) == 2
    end
  end

  describe "repeater utilities" do
    test "advance_repeater is alias for next_occurrence" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1w>")

      advanced = Org.Timestamp.advance_repeater(timestamp)
      next = Org.Timestamp.next_occurrence(timestamp)

      assert advanced == next
    end

    test "repeats_on_or_after? checks if timestamp occurs on/after date" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon +1w>")

      assert Org.Timestamp.repeats_on_or_after?(timestamp, ~D[2024-01-15]) == true
      assert Org.Timestamp.repeats_on_or_after?(timestamp, ~D[2024-01-22]) == true
      assert Org.Timestamp.repeats_on_or_after?(timestamp, ~D[2024-01-10]) == true
    end

    test "repeater_interval_days calculates approximate days" do
      assert Org.Timestamp.repeater_interval_days(%{count: 1, unit: :day}) == 1
      assert Org.Timestamp.repeater_interval_days(%{count: 2, unit: :week}) == 14
      assert Org.Timestamp.repeater_interval_days(%{count: 1, unit: :month}) == 30
      assert Org.Timestamp.repeater_interval_days(%{count: 1, unit: :year}) == 365
      assert Org.Timestamp.repeater_interval_days(%{count: 3, unit: :hour}) == 0
    end
  end

  describe "repeating task completion" do
    test "completing repeating task advances timestamp and resets to TODO" do
      doc =
        Org.load_string("""
        * TODO Weekly Meeting
          SCHEDULED: <2024-01-15 Mon 09:00 +1w>
        """)

      doc = Org.complete_repeating_task(doc, ["Weekly Meeting"])
      task = Org.section(doc, ["Weekly Meeting"])

      assert task.todo_keyword == "TODO"
      assert task.metadata.scheduled.date == ~D[2024-01-22]
      assert task.metadata.scheduled.start_time == ~T[09:00:00]
    end

    test "completing non-repeating task marks as DONE" do
      doc =
        Org.load_string("""
        * TODO One-time Task
          SCHEDULED: <2024-01-15 Mon 09:00>
        """)

      doc = Org.complete_repeating_task(doc, ["One-time Task"])
      task = Org.section(doc, ["One-time Task"])

      assert task.todo_keyword == "DONE"
      assert task.metadata.closed != nil
    end

    test "advances both scheduled and deadline if repeating" do
      doc =
        Org.load_string("""
        * TODO Weekly Report
          SCHEDULED: <2024-01-15 Mon 09:00 +1w>
          DEADLINE: <2024-01-17 Wed 17:00 +1w>
        """)

      doc = Org.complete_repeating_task(doc, ["Weekly Report"])
      task = Org.section(doc, ["Weekly Report"])

      assert task.todo_keyword == "TODO"
      assert task.metadata.scheduled.date == ~D[2024-01-22]
      assert task.metadata.deadline.date == ~D[2024-01-24]
    end

    test "regular complete_task works with repeaters" do
      doc =
        Org.load_string("""
        * TODO Daily Standup
          SCHEDULED: <2024-01-15 Mon 09:00 +1d>
        """)

      completion_time = DateTime.from_naive!(~N[2024-01-15 09:15:00], "Etc/UTC")
      doc = Org.complete_task(doc, ["Daily Standup"], completion_time)
      task = Org.section(doc, ["Daily Standup"])

      # Should advance to next occurrence and reset to TODO
      assert task.todo_keyword == "TODO"
      assert task.metadata.scheduled.date == ~D[2024-01-16]
      # Should also have CLOSED timestamp for this completion
      assert task.metadata.closed != nil
    end
  end

  describe "advance repeaters function" do
    test "advances all repeating timestamps in section" do
      doc =
        Org.load_string("""
        * TODO Weekly Meeting
          SCHEDULED: <2024-01-15 Mon 09:00 +1w>
          DEADLINE: <2024-01-17 Wed 17:00 +1w>
        """)

      doc = Org.advance_repeaters(doc, ["Weekly Meeting"])
      task = Org.section(doc, ["Weekly Meeting"])

      assert task.metadata.scheduled.date == ~D[2024-01-22]
      assert task.metadata.deadline.date == ~D[2024-01-24]
    end

    test "leaves non-repeating timestamps unchanged" do
      doc =
        Org.load_string("""
        * TODO Mixed Task
          SCHEDULED: <2024-01-15 Mon 09:00 +1w>
          DEADLINE: <2024-01-17 Wed 17:00>
        """)

      doc = Org.advance_repeaters(doc, ["Mixed Task"])
      task = Org.section(doc, ["Mixed Task"])

      # Scheduled should advance (has repeater)
      assert task.metadata.scheduled.date == ~D[2024-01-22]
      # Deadline should remain unchanged (no repeater)
      assert task.metadata.deadline.date == ~D[2024-01-17]
    end
  end

  describe "repeater scheduling functions" do
    test "schedule_repeating sets repeating scheduled timestamp" do
      doc = Org.load_string("* Task")
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon 09:00 +1w>")

      doc = Org.schedule_repeating(doc, ["Task"], timestamp)
      task = Org.section(doc, ["Task"])

      assert Org.Timestamp.repeating?(task.metadata.scheduled)
      assert task.metadata.scheduled.date == ~D[2024-01-15]
    end

    test "schedule_repeating raises on non-repeating timestamp" do
      doc = Org.load_string("* Task")
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon 09:00>")

      assert_raise ArgumentError, fn ->
        Org.schedule_repeating(doc, ["Task"], timestamp)
      end
    end

    test "deadline_repeating sets repeating deadline timestamp" do
      doc = Org.load_string("* Task")
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-17 Wed 17:00 +1w>")

      doc = Org.deadline_repeating(doc, ["Task"], timestamp)
      task = Org.section(doc, ["Task"])

      assert Org.Timestamp.repeating?(task.metadata.deadline)
      assert task.metadata.deadline.date == ~D[2024-01-17]
    end
  end

  describe "repeater queries" do
    test "has_repeating_timestamps? detects repeating timestamps" do
      doc1 = Org.load_string("* Task\n  SCHEDULED: <2024-01-15 Mon +1w>")
      doc2 = Org.load_string("* Task\n  SCHEDULED: <2024-01-15 Mon>")

      task1 = Org.section(doc1, ["Task"])
      task2 = Org.section(doc2, ["Task"])

      assert Org.has_repeating_timestamps?(task1.metadata) == true
      assert Org.has_repeating_timestamps?(task2.metadata) == false
    end

    test "repeating_sections extracts sections with repeating timestamps" do
      doc =
        Org.load_string("""
        * TODO Daily Standup
          SCHEDULED: <2024-01-15 Mon 09:00 +1d>
        * TODO One-time Meeting
          SCHEDULED: <2024-01-16 Tue 10:00>
        * TODO Weekly Review
          DEADLINE: <2024-01-19 Fri +1w>
        """)

      repeating_tasks = Org.repeating_sections(doc)

      assert length(repeating_tasks) == 2
      titles = Enum.map(repeating_tasks, & &1.title)
      assert "Daily Standup" in titles
      assert "Weekly Review" in titles
      refute "One-time Meeting" in titles
    end
  end

  describe "agenda with repeaters" do
    test "agenda_items_with_repeaters includes repeating occurrences" do
      doc =
        Org.load_string("""
        * TODO Daily Meeting
          SCHEDULED: <2024-01-10 Wed 09:00 +1d>
        * TODO One-time Task
          SCHEDULED: <2024-01-15 Mon 10:00>
        * TODO Weekly Review
          SCHEDULED: <2024-01-08 Mon 14:00 +1w>
        """)

      # Check what's scheduled for Monday Jan 15
      agenda = Org.agenda_items_with_repeaters(doc, ~D[2024-01-15])

      titles = Enum.map(agenda, & &1.title)
      # Repeats daily, so occurs on Jan 15
      assert "Daily Meeting" in titles
      # Scheduled exactly for Jan 15
      assert "One-time Task" in titles
      # Repeats weekly from Jan 8, so occurs on Jan 15
      assert "Weekly Review" in titles
      assert length(agenda) == 3
    end

    test "agenda_items_with_repeaters excludes non-matching dates" do
      doc =
        Org.load_string("""
        * TODO Daily Meeting
          SCHEDULED: <2024-01-10 Wed 09:00 +1d>
        * TODO Wrong Date Task
          SCHEDULED: <2024-01-16 Tue 10:00>
        """)

      agenda = Org.agenda_items_with_repeaters(doc, ~D[2024-01-15])

      titles = Enum.map(agenda, & &1.title)
      assert "Daily Meeting" in titles
      refute "Wrong Date Task" in titles
      assert length(agenda) == 1
    end
  end

  describe "overdue with repeaters" do
    test "overdue_items_with_repeaters handles repeating deadlines correctly" do
      doc =
        Org.load_string("""
        * TODO Weekly Report
          DEADLINE: <2024-01-10 Wed +1w>
        * TODO Overdue Task
          DEADLINE: <2024-01-10 Wed>
        * DONE Completed Task
          DEADLINE: <2024-01-05 Fri>
        """)

      # Check overdue items as of Jan 15
      overdue = Org.overdue_items_with_repeaters(doc, ~D[2024-01-15])

      titles = Enum.map(overdue, & &1.title)
      # Weekly report repeats weekly, so next deadline would be Jan 17, not overdue
      refute "Weekly Report" in titles
      # This task had a deadline on Jan 10 and is overdue
      assert "Overdue Task" in titles
      # DONE tasks are not considered overdue
      refute "Completed Task" in titles
      assert length(overdue) == 1
    end
  end

  describe "repeater occurrences in range" do
    test "finds all occurrences of repeating tasks in date range" do
      doc =
        Org.load_string("""
        * TODO Daily Standup
          SCHEDULED: <2024-01-15 Mon 09:00 +1d>
        * TODO Weekly Review
          DEADLINE: <2024-01-12 Fri 17:00 +1w>
        """)

      occurrences = Org.repeater_occurrences_in_range(doc, ~D[2024-01-15], ~D[2024-01-20])

      # Should find daily standup occurrences (Jan 15-20 = 6 days)
      # Plus weekly review deadline (Jan 19)
      assert length(occurrences) == 7

      # Check that we get section-timestamp pairs
      {first_section, first_timestamp} = hd(occurrences)
      assert is_struct(first_section, Org.Section)
      assert is_struct(first_timestamp, Org.Timestamp)
    end
  end

  describe "serialization with repeaters" do
    test "serializes advanced repeaters correctly" do
      doc =
        Org.load_string("""
        * TODO Weekly Meeting
          SCHEDULED: <2024-01-15 Mon 09:00-10:00 +1w>
        """)

      doc = Org.advance_repeaters(doc, ["Weekly Meeting"])
      serialized = Org.to_org_string(doc)

      assert serialized =~ "SCHEDULED: <2024-01-22 Mon 09:00-10:00 +1w>"
    end

    test "round-trip parsing preserves repeater information" do
      original = """
      * TODO Daily Standup
        SCHEDULED: <2024-01-15 Mon 09:00 +1d>
        DEADLINE: <2024-01-15 Mon 18:00 +1d>
      """

      doc = Org.load_string(original)
      doc = Org.advance_repeaters(doc, ["Daily Standup"])
      serialized = Org.to_org_string(doc)
      reparsed = Org.load_string(serialized)

      task = Org.section(reparsed, ["Daily Standup"])
      assert task.metadata.scheduled.repeater == %{count: 1, unit: :day}
      assert task.metadata.deadline.repeater == %{count: 1, unit: :day}
      assert task.metadata.scheduled.date == ~D[2024-01-16]
      assert task.metadata.deadline.date == ~D[2024-01-16]
    end
  end

  describe "edge cases" do
    test "handles sections without metadata gracefully" do
      doc = Org.load_string("* Regular Section")
      task = Org.section(doc, ["Regular Section"])

      assert Org.has_repeating_timestamps?(task.metadata) == false

      # Should not crash
      _doc = Org.advance_repeaters(doc, ["Regular Section"])
      _doc = Org.complete_repeating_task(doc, ["Regular Section"])
    end

    test "handles mixed repeating and non-repeating timestamps" do
      doc =
        Org.load_string("""
        * TODO Mixed Task
          SCHEDULED: <2024-01-15 Mon +1w>
          DEADLINE: <2024-01-20 Sat>
        """)

      # Should detect as having repeating timestamps
      task = Org.section(doc, ["Mixed Task"])
      assert Org.has_repeating_timestamps?(task.metadata) == true

      # Should advance only the repeating one
      doc = Org.advance_repeaters(doc, ["Mixed Task"])
      task = Org.section(doc, ["Mixed Task"])

      assert task.metadata.scheduled.date == ~D[2024-01-22]
      # Unchanged
      assert task.metadata.deadline.date == ~D[2024-01-20]
    end

    test "handles hourly repeaters properly" do
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon 09:00 +4h>")
      next = Org.Timestamp.next_occurrence(timestamp)

      # Hourly repeaters don't change the date, just time
      assert next.date == ~D[2024-01-15]
      # Time stays same since we only track date
      assert next.start_time == ~T[09:00:00]
    end
  end
end
