defmodule Org.TimestampTest do
  use ExUnit.Case
  doctest Org.Timestamp

  alias Org.Timestamp

  describe "parse/1" do
    test "parses basic active timestamp" do
      {:ok, timestamp} = Timestamp.parse("<2024-01-15 Mon>")

      assert timestamp.type == :active
      assert timestamp.date == ~D[2024-01-15]
      assert timestamp.day_name == "Mon"
      assert timestamp.start_time == nil
      assert timestamp.end_time == nil
      assert timestamp.repeater == nil
      assert timestamp.warning == nil
      assert timestamp.raw == "<2024-01-15 Mon>"
    end

    test "parses basic inactive timestamp" do
      {:ok, timestamp} = Timestamp.parse("[2024-01-15 Mon]")

      assert timestamp.type == :inactive
      assert timestamp.date == ~D[2024-01-15]
      assert timestamp.day_name == "Mon"
    end

    test "parses timestamp without day name" do
      {:ok, timestamp} = Timestamp.parse("<2024-01-15>")

      assert timestamp.type == :active
      assert timestamp.date == ~D[2024-01-15]
      assert timestamp.day_name == nil
    end

    test "parses timestamp with time" do
      {:ok, timestamp} = Timestamp.parse("<2024-01-15 Mon 14:30>")

      assert timestamp.type == :active
      assert timestamp.date == ~D[2024-01-15]
      assert timestamp.start_time == ~T[14:30:00]
      assert timestamp.end_time == nil
    end

    test "parses timestamp with time range" do
      {:ok, timestamp} = Timestamp.parse("<2024-01-15 Mon 14:30-16:00>")

      assert timestamp.type == :active
      assert timestamp.date == ~D[2024-01-15]
      assert timestamp.start_time == ~T[14:30:00]
      assert timestamp.end_time == ~T[16:00:00]
    end

    test "parses timestamp with repeater" do
      {:ok, timestamp} = Timestamp.parse("<2024-01-15 Mon +1w>")

      assert timestamp.repeater == %{count: 1, unit: :week, type: :regular}
    end

    test "parses timestamp with warning" do
      {:ok, timestamp} = Timestamp.parse("<2024-01-15 Mon -2d>")

      assert timestamp.warning == %{count: 2, unit: :day}
    end

    test "parses timestamp with both repeater and warning" do
      {:ok, timestamp} = Timestamp.parse("<2024-01-15 Mon +1w -2d>")

      assert timestamp.repeater == %{count: 1, unit: :week, type: :regular}
      assert timestamp.warning == %{count: 2, unit: :day}
    end

    test "parses complex timestamp" do
      {:ok, timestamp} = Timestamp.parse("<2024-01-15 Mon 14:30-16:00 +1w -2d>")

      assert timestamp.type == :active
      assert timestamp.date == ~D[2024-01-15]
      assert timestamp.day_name == "Mon"
      assert timestamp.start_time == ~T[14:30:00]
      assert timestamp.end_time == ~T[16:00:00]
      assert timestamp.repeater == %{count: 1, unit: :week, type: :regular}
      assert timestamp.warning == %{count: 2, unit: :day}
    end

    test "parses different time units" do
      test_cases = [
        {"+5h", %{count: 5, unit: :hour, type: :regular}},
        {"+3d", %{count: 3, unit: :day, type: :regular}},
        {"+2w", %{count: 2, unit: :week, type: :regular}},
        {"+1m", %{count: 1, unit: :month, type: :regular}},
        {"+1y", %{count: 1, unit: :year, type: :regular}}
      ]

      for {suffix, expected} <- test_cases do
        {:ok, timestamp} = Timestamp.parse("<2024-01-15 #{suffix}>")
        assert timestamp.repeater == expected
      end
    end

    test "handles whitespace variations" do
      test_cases = [
        "  <2024-01-15 Mon>  ",
        "<2024-01-15  Mon>",
        "<2024-01-15 Mon  14:30>",
        "<2024-01-15 Mon +1w  -2d>"
      ]

      for timestamp_str <- test_cases do
        {:ok, timestamp} = Timestamp.parse(timestamp_str)
        assert timestamp.date == ~D[2024-01-15]
      end
    end

    test "returns error for invalid format" do
      invalid_cases = [
        # Missing brackets
        "2024-01-15 Mon",
        # Invalid date
        "<invalid-date>",
        # Invalid time
        "<2024-01-15 Mon 25:30>",
        # Zero repeater
        "<2024-01-15 Mon +0w>",
        # Invalid month
        "<2024-13-01>",
        # Empty string
        ""
      ]

      for invalid <- invalid_cases do
        assert {:error, _} = Timestamp.parse(invalid)
      end
    end
  end

  describe "parse!/1" do
    test "returns timestamp on success" do
      timestamp = Timestamp.parse!("<2024-01-15 Mon>")
      assert timestamp.date == ~D[2024-01-15]
    end

    test "raises on error" do
      assert_raise ArgumentError, fn ->
        Timestamp.parse!("invalid")
      end
    end
  end

  describe "to_string/1" do
    test "renders basic active timestamp" do
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        day_name: "Mon",
        raw: "<2024-01-15 Mon>"
      }

      assert Timestamp.to_string(timestamp) == "<2024-01-15 Mon>"
    end

    test "renders basic inactive timestamp" do
      timestamp = %Timestamp{
        type: :inactive,
        date: ~D[2024-01-15],
        day_name: "Mon",
        raw: "[2024-01-15 Mon]"
      }

      assert Timestamp.to_string(timestamp) == "[2024-01-15 Mon]"
    end

    test "renders timestamp without day name" do
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        raw: "<2024-01-15>"
      }

      assert Timestamp.to_string(timestamp) == "<2024-01-15>"
    end

    test "renders timestamp with time" do
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        day_name: "Mon",
        start_time: ~T[14:30:00],
        raw: "<2024-01-15 Mon 14:30>"
      }

      assert Timestamp.to_string(timestamp) == "<2024-01-15 Mon 14:30>"
    end

    test "renders timestamp with time range" do
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        day_name: "Mon",
        start_time: ~T[14:30:00],
        end_time: ~T[16:00:00],
        raw: "<2024-01-15 Mon 14:30-16:00>"
      }

      assert Timestamp.to_string(timestamp) == "<2024-01-15 Mon 14:30-16:00>"
    end

    test "renders timestamp with repeater" do
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        day_name: "Mon",
        repeater: %{count: 1, unit: :week},
        raw: "<2024-01-15 Mon +1w>"
      }

      assert Timestamp.to_string(timestamp) == "<2024-01-15 Mon +1w>"
    end

    test "renders timestamp with warning" do
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        day_name: "Mon",
        warning: %{count: 2, unit: :day},
        raw: "<2024-01-15 Mon -2d>"
      }

      assert Timestamp.to_string(timestamp) == "<2024-01-15 Mon -2d>"
    end

    test "renders complex timestamp" do
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        day_name: "Mon",
        start_time: ~T[14:30:00],
        end_time: ~T[16:00:00],
        repeater: %{count: 1, unit: :week},
        warning: %{count: 2, unit: :day},
        raw: "<2024-01-15 Mon 14:30-16:00 +1w -2d>"
      }

      assert Timestamp.to_string(timestamp) == "<2024-01-15 Mon 14:30-16:00 +1w -2d>"
    end
  end

  describe "roundtrip parsing" do
    test "parse and render should be idempotent" do
      test_cases = [
        "<2024-01-15 Mon>",
        "[2024-01-15 Mon]",
        "<2024-01-15>",
        "<2024-01-15 Mon 14:30>",
        "<2024-01-15 Mon 14:30-16:00>",
        "<2024-01-15 Mon +1w>",
        "<2024-01-15 Mon -2d>",
        "<2024-01-15 Mon 14:30-16:00 +1w -2d>",
        "[2024-12-25 Wed 09:00 +1y -1w]"
      ]

      for original <- test_cases do
        {:ok, timestamp} = Timestamp.parse(original)
        rendered = Timestamp.to_string(timestamp)
        assert rendered == original, "Failed for: #{original}"
      end
    end
  end

  describe "utility functions" do
    test "active?/1" do
      active_timestamp = %Timestamp{type: :active, date: ~D[2024-01-15], raw: "<2024-01-15>"}
      inactive_timestamp = %Timestamp{type: :inactive, date: ~D[2024-01-15], raw: "[2024-01-15]"}

      assert Timestamp.active?(active_timestamp) == true
      assert Timestamp.active?(inactive_timestamp) == false
    end

    test "has_time?/1" do
      with_time = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        start_time: ~T[14:30:00],
        raw: "<2024-01-15 14:30>"
      }

      without_time = %Timestamp{type: :active, date: ~D[2024-01-15], raw: "<2024-01-15>"}

      assert Timestamp.has_time?(with_time) == true
      assert Timestamp.has_time?(without_time) == false
    end

    test "time_range?/1" do
      with_range = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        start_time: ~T[14:30:00],
        end_time: ~T[16:00:00],
        raw: "<2024-01-15 14:30-16:00>"
      }

      without_range = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        start_time: ~T[14:30:00],
        raw: "<2024-01-15 14:30>"
      }

      assert Timestamp.time_range?(with_range) == true
      assert Timestamp.time_range?(without_range) == false
    end

    test "repeating?/1" do
      with_repeater = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        repeater: %{count: 1, unit: :week},
        raw: "<2024-01-15 +1w>"
      }

      without_repeater = %Timestamp{type: :active, date: ~D[2024-01-15], raw: "<2024-01-15>"}

      assert Timestamp.repeating?(with_repeater) == true
      assert Timestamp.repeating?(without_repeater) == false
    end
  end

  describe "datetime conversion" do
    test "to_datetime/1 with time" do
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        start_time: ~T[14:30:00],
        raw: "<2024-01-15 14:30>"
      }

      datetime = Timestamp.to_datetime(timestamp)
      assert DateTime.to_date(datetime) == ~D[2024-01-15]
      assert DateTime.to_time(datetime) == ~T[14:30:00]
    end

    test "to_datetime/1 without time defaults to noon" do
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        raw: "<2024-01-15>"
      }

      datetime = Timestamp.to_datetime(timestamp)
      assert DateTime.to_date(datetime) == ~D[2024-01-15]
      assert DateTime.to_time(datetime) == ~T[12:00:00]
    end

    test "end_datetime/1 with time range" do
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        start_time: ~T[14:30:00],
        end_time: ~T[16:00:00],
        raw: "<2024-01-15 14:30-16:00>"
      }

      end_datetime = Timestamp.end_datetime(timestamp)
      assert DateTime.to_date(end_datetime) == ~D[2024-01-15]
      assert DateTime.to_time(end_datetime) == ~T[16:00:00]
    end

    test "end_datetime/1 without end time" do
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        start_time: ~T[14:30:00],
        raw: "<2024-01-15 14:30>"
      }

      assert Timestamp.end_datetime(timestamp) == nil
    end
  end

  describe "timezone support" do
    test "parses timestamps with timezone offsets" do
      assert {:ok, timestamp} = Timestamp.parse("<2024-01-15 14:30 +02:00>")
      assert timestamp.timezone == "+02:00"
      assert timestamp.date == ~D[2024-01-15]
      assert timestamp.start_time == ~T[14:30:00]
    end

    test "parses timestamps with negative timezone offsets" do
      assert {:ok, timestamp} = Timestamp.parse("<2024-01-15 14:30 -05:00>")
      assert timestamp.timezone == "-05:00"
    end

    test "parses timestamps with named timezones" do
      assert {:ok, timestamp} = Timestamp.parse("<2024-01-15 14:30 UTC>")
      assert timestamp.timezone == "UTC"
    end

    test "parses timestamps with timezone abbreviations" do
      assert {:ok, timestamp} = Timestamp.parse("<2024-01-15 14:30 EST>")
      assert timestamp.timezone == "EST"
    end

    test "formats timestamps with timezones correctly" do
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        start_time: ~T[14:30:00],
        timezone: "+02:00",
        raw: "<2024-01-15 14:30 +02:00>"
      }

      assert Timestamp.to_string(timestamp) == "<2024-01-15 14:30 +02:00>"
    end
  end

  describe "enhanced repeater types" do
    test "parses regular repeater (+)" do
      assert {:ok, timestamp} = Timestamp.parse("<2024-01-15 14:30 +1w>")
      assert timestamp.repeater == %{count: 1, unit: :week, type: :regular}
    end

    test "parses cumulative repeater (++)" do
      assert {:ok, timestamp} = Timestamp.parse("<2024-01-15 14:30 ++1w>")
      assert timestamp.repeater == %{count: 1, unit: :week, type: :cumulative}
    end

    test "parses catch-up repeater (.+)" do
      assert {:ok, timestamp} = Timestamp.parse("<2024-01-15 14:30 .+1w>")
      assert timestamp.repeater == %{count: 1, unit: :week, type: :catch_up}
    end

    test "formats regular repeater correctly" do
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        start_time: ~T[14:30:00],
        repeater: %{count: 1, unit: :week, type: :regular},
        raw: "<2024-01-15 14:30 +1w>"
      }

      assert Timestamp.to_string(timestamp) == "<2024-01-15 14:30 +1w>"
    end

    test "formats cumulative repeater correctly" do
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        start_time: ~T[14:30:00],
        repeater: %{count: 2, unit: :day, type: :cumulative},
        raw: "<2024-01-15 14:30 ++2d>"
      }

      assert Timestamp.to_string(timestamp) == "<2024-01-15 14:30 ++2d>"
    end

    test "formats catch-up repeater correctly" do
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        start_time: ~T[14:30:00],
        repeater: %{count: 1, unit: :month, type: :catch_up},
        raw: "<2024-01-15 14:30 .+1m>"
      }

      assert Timestamp.to_string(timestamp) == "<2024-01-15 14:30 .+1m>"
    end

    test "maintains backwards compatibility for repeaters without type" do
      # Old format should still work
      timestamp = %Timestamp{
        type: :active,
        date: ~D[2024-01-15],
        start_time: ~T[14:30:00],
        repeater: %{count: 1, unit: :week},
        raw: "<2024-01-15 14:30 +1w>"
      }

      assert Timestamp.to_string(timestamp) == "<2024-01-15 14:30 +1w>"
    end
  end

  describe "complex timestamp combinations" do
    test "parses timestamps with all components" do
      assert {:ok, timestamp} = Timestamp.parse("<2024-01-15 Mon 14:30-16:00 EST ++1w -2d>")

      assert timestamp.date == ~D[2024-01-15]
      assert timestamp.day_name == "Mon"
      assert timestamp.start_time == ~T[14:30:00]
      assert timestamp.end_time == ~T[16:00:00]
      assert timestamp.timezone == "EST"
      assert timestamp.repeater == %{count: 1, unit: :week, type: :cumulative}
      assert timestamp.warning == %{count: 2, unit: :day}
    end

    test "round-trip parsing preserves all data" do
      original = "<2024-01-15 Mon 14:30-16:00 EST .+1m -1w>"

      assert {:ok, timestamp} = Timestamp.parse(original)
      formatted = Timestamp.to_string(timestamp)
      assert {:ok, reparsed} = Timestamp.parse(formatted)

      assert timestamp == reparsed
    end

    test "parses inactive timestamps with complex patterns" do
      assert {:ok, timestamp} = Timestamp.parse("[2024-01-15 Mon 14:30 UTC ++1m -1w]")

      assert timestamp.type == :inactive
      assert timestamp.timezone == "UTC"
      assert timestamp.repeater.type == :cumulative
    end
  end
end
