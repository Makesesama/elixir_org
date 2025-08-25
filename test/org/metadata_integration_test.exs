defmodule Org.MetadataIntegrationTest do
  use ExUnit.Case

  alias Org.{FragmentParser, PropertyDrawer, Timestamp}

  describe "timestamp integration with PropertyDrawer" do
    test "parses timestamps correctly" do
      lines = [
        "SCHEDULED: <2024-01-15 Mon 14:30>",
        "DEADLINE: <2024-01-20 Sat -2d>",
        "CLOSED: [2024-01-18 Thu]",
        "Regular content"
      ]

      {metadata, remaining} = PropertyDrawer.parse_metadata(lines)

      # SCHEDULED timestamp
      assert %Timestamp{} = metadata.scheduled
      assert metadata.scheduled.type == :active
      assert metadata.scheduled.date == ~D[2024-01-15]
      assert metadata.scheduled.start_time == ~T[14:30:00]
      assert metadata.scheduled.day_name == "Mon"

      # DEADLINE timestamp with warning
      assert %Timestamp{} = metadata.deadline
      assert metadata.deadline.type == :active
      assert metadata.deadline.date == ~D[2024-01-20]
      assert metadata.deadline.day_name == "Sat"
      assert metadata.deadline.warning == %{count: 2, unit: :day}

      # CLOSED timestamp (inactive)
      assert %Timestamp{} = metadata.closed
      assert metadata.closed.type == :inactive
      assert metadata.closed.date == ~D[2024-01-18]
      assert metadata.closed.day_name == "Thu"

      assert remaining == ["Regular content"]
    end

    test "renders timestamps back correctly" do
      metadata = %{
        scheduled: Timestamp.parse!("<2024-01-15 Mon 14:30>"),
        deadline: Timestamp.parse!("<2024-01-20 Sat -2d>"),
        closed: Timestamp.parse!("[2024-01-18 Thu]")
      }

      rendered_lines = PropertyDrawer.render_metadata(metadata)

      assert "  SCHEDULED: <2024-01-15 Mon 14:30>" in rendered_lines
      assert "  DEADLINE: <2024-01-20 Sat -2d>" in rendered_lines
      assert "  CLOSED: [2024-01-18 Thu]" in rendered_lines
    end

    test "handles mixed timestamp and string metadata" do
      # When timestamp parsing fails, should fall back to string
      lines = [
        "SCHEDULED: <2024-01-15 Mon>",
        "DEADLINE: invalid-timestamp",
        "Content"
      ]

      {metadata, remaining} = PropertyDrawer.parse_metadata(lines)

      assert %Timestamp{} = metadata.scheduled
      assert metadata.scheduled.date == ~D[2024-01-15]

      # Should fall back to string for invalid timestamp
      assert is_binary(metadata.deadline)
      assert metadata.deadline == "invalid-timestamp"

      assert remaining == ["Content"]
    end
  end

  describe "FragmentParser integration with typed timestamps" do
    test "parses section with typed metadata" do
      text = """
      * TODO Important Task
        SCHEDULED: <2024-01-15 Mon 14:30-16:00>
        DEADLINE: <2024-01-20 Sat -2d>
      """

      fragment = FragmentParser.parse_fragment(text)

      assert fragment.type == :section
      assert fragment.content.title == "Important Task"
      assert fragment.content.todo_keyword == "TODO"

      # Check scheduled timestamp
      assert %Timestamp{} = fragment.content.metadata.scheduled
      scheduled = fragment.content.metadata.scheduled
      assert scheduled.type == :active
      assert scheduled.date == ~D[2024-01-15]
      assert scheduled.start_time == ~T[14:30:00]
      assert scheduled.end_time == ~T[16:00:00]

      # Check deadline timestamp
      assert %Timestamp{} = fragment.content.metadata.deadline
      deadline = fragment.content.metadata.deadline
      assert deadline.type == :active
      assert deadline.date == ~D[2024-01-20]
      assert deadline.warning == %{count: 2, unit: :day}
    end

    test "renders section with typed metadata back to org format" do
      text = """
      * TODO Task
        SCHEDULED: <2024-01-15 Mon 14:30>
        DEADLINE: <2024-01-20 Sat>
      """

      fragment = FragmentParser.parse_fragment(text)
      rendered = FragmentParser.render_fragment(fragment)

      assert rendered =~ "* TODO Task"
      assert rendered =~ "SCHEDULED: <2024-01-15 Mon 14:30>"
      assert rendered =~ "DEADLINE: <2024-01-20 Sat>"
    end

    test "works with properties and typed metadata together" do
      text = """
      ** DONE [#A] Complex Task :work:
         :PROPERTIES:
         :ID: task-001
         :Effort: 2h
         :END:
         SCHEDULED: <2024-01-10 Wed 09:00>
         CLOSED: [2024-01-10 Wed 11:00]
      """

      fragment = FragmentParser.parse_fragment(text)

      # Check basic section info
      assert fragment.content.title == "Complex Task"
      assert fragment.content.todo_keyword == "DONE"
      assert fragment.content.priority == "A"
      assert fragment.content.tags == ["work"]

      # Check properties (still strings)
      assert fragment.content.properties == %{
               "ID" => "task-001",
               "Effort" => "2h"
             }

      # Check typed metadata
      assert %Timestamp{} = fragment.content.metadata.scheduled
      assert fragment.content.metadata.scheduled.type == :active
      assert fragment.content.metadata.scheduled.date == ~D[2024-01-10]
      assert fragment.content.metadata.scheduled.start_time == ~T[09:00:00]

      assert %Timestamp{} = fragment.content.metadata.closed
      assert fragment.content.metadata.closed.type == :inactive
      assert fragment.content.metadata.closed.date == ~D[2024-01-10]
      assert fragment.content.metadata.closed.start_time == ~T[11:00:00]
    end
  end

  describe "datetime utility functions" do
    test "converts timestamps to DateTime objects" do
      text = """
      * Meeting
        SCHEDULED: <2024-01-15 Mon 14:30-16:00>
      """

      fragment = FragmentParser.parse_fragment(text)
      scheduled = fragment.content.metadata.scheduled

      # Test start datetime
      start_dt = Timestamp.to_datetime(scheduled)
      assert DateTime.to_date(start_dt) == ~D[2024-01-15]
      assert DateTime.to_time(start_dt) == ~T[14:30:00]

      # Test end datetime
      end_dt = Timestamp.end_datetime(scheduled)
      assert DateTime.to_date(end_dt) == ~D[2024-01-15]
      assert DateTime.to_time(end_dt) == ~T[16:00:00]
    end

    test "utility functions work correctly" do
      text = """
      * Task
        SCHEDULED: <2024-01-15 Mon 14:30 +1w -2d>
      """

      fragment = FragmentParser.parse_fragment(text)
      timestamp = fragment.content.metadata.scheduled

      assert Timestamp.active?(timestamp) == true
      assert Timestamp.has_time?(timestamp) == true
      assert Timestamp.time_range?(timestamp) == false
      assert Timestamp.repeating?(timestamp) == true
    end
  end

  describe "JSON encoding with typed timestamps" do
    test "properly serializes timestamps in JSON" do
      text = """
      * Task
        SCHEDULED: <2024-01-15 Mon 14:30-16:00>
        DEADLINE: <2024-01-20 Sat +1w -2d>
      """

      fragment = FragmentParser.parse_fragment(text)
      json_data = Org.JSONEncoder.encode(fragment.content)

      # Check that metadata is properly structured
      assert is_map(json_data.metadata)

      # Check scheduled timestamp encoding
      scheduled_json = json_data.metadata.scheduled
      assert scheduled_json.type == "timestamp"
      assert scheduled_json.timestamp_type == :active
      assert scheduled_json.date == "2024-01-15"
      assert scheduled_json.start_time == "14:30:00"
      assert scheduled_json.end_time == "16:00:00"

      # Check deadline timestamp encoding
      deadline_json = json_data.metadata.deadline
      assert deadline_json.type == "timestamp"
      assert deadline_json.repeater == %{count: 1, unit: :week}
      assert deadline_json.warning == %{count: 2, unit: :day}
    end
  end
end
