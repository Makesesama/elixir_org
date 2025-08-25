defmodule Org.PropertyDrawerTest do
  use ExUnit.Case
  doctest Org.PropertyDrawer

  alias Org.PropertyDrawer

  describe "parse_drawer/1" do
    test "parses valid property drawer" do
      lines = [
        ":PROPERTIES:",
        ":ID: 12345",
        ":Author: John Doe",
        ":Date: 2024-01-15",
        ":END:",
        "Content after drawer"
      ]

      {properties, remaining} = PropertyDrawer.parse_drawer(lines)

      assert properties == %{
               "ID" => "12345",
               "Author" => "John Doe",
               "Date" => "2024-01-15"
             }

      assert remaining == ["Content after drawer"]
    end

    test "handles empty property drawer" do
      lines = [":PROPERTIES:", ":END:", "Content"]

      {properties, remaining} = PropertyDrawer.parse_drawer(lines)

      assert properties == %{}
      assert remaining == ["Content"]
    end

    test "handles non-property drawer lines" do
      lines = ["Not a property drawer", "Just regular content"]

      {properties, remaining} = PropertyDrawer.parse_drawer(lines)

      assert properties == %{}
      assert remaining == lines
    end

    test "handles property drawer with whitespace" do
      lines = [
        ":PROPERTIES:",
        "  :Title: My Title  ",
        "  :Tags: tag1 tag2  ",
        ":END:"
      ]

      {properties, _} = PropertyDrawer.parse_drawer(lines)

      assert properties == %{
               "Title" => "My Title",
               "Tags" => "tag1 tag2"
             }
    end

    test "handles unclosed property drawer" do
      lines = [
        ":PROPERTIES:",
        ":Key: Value"
      ]

      {properties, remaining} = PropertyDrawer.parse_drawer(lines)

      assert properties == %{"Key" => "Value"}
      assert remaining == []
    end
  end

  describe "parse_property_line/1" do
    test "parses valid property line" do
      assert PropertyDrawer.parse_property_line(":Key: Value") == {"Key", "Value"}
      assert PropertyDrawer.parse_property_line(":Title: My Title") == {"Title", "My Title"}
      assert PropertyDrawer.parse_property_line("  :Spaces:  Value  ") == {"Spaces", "Value"}
    end

    test "handles property with colons in value" do
      assert PropertyDrawer.parse_property_line(":URL: https://example.com") ==
               {"URL", "https://example.com"}
    end

    test "returns nil for invalid lines" do
      assert PropertyDrawer.parse_property_line("Not a property") == nil
      assert PropertyDrawer.parse_property_line(":NoValue") == nil
      assert PropertyDrawer.parse_property_line("Key: Value") == nil
    end
  end

  describe "parse_metadata/1" do
    test "parses SCHEDULED metadata" do
      lines = [
        "SCHEDULED: <2024-01-15 Mon>",
        "Content"
      ]

      {metadata, remaining} = PropertyDrawer.parse_metadata(lines)

      assert %{scheduled: %Org.Timestamp{}} = metadata
      assert metadata.scheduled.type == :active
      assert metadata.scheduled.date == ~D[2024-01-15]
      assert metadata.scheduled.day_name == "Mon"
      assert remaining == ["Content"]
    end

    test "parses DEADLINE metadata" do
      lines = [
        "DEADLINE: <2024-01-20 Sat>",
        "Some content"
      ]

      {metadata, remaining} = PropertyDrawer.parse_metadata(lines)

      assert %Org.Timestamp{} = metadata.deadline
      assert metadata.deadline.type == :active
      assert metadata.deadline.date == ~D[2024-01-20]
      assert metadata.deadline.day_name == "Sat"
      assert remaining == ["Some content"]
    end

    test "parses CLOSED metadata" do
      lines = [
        "CLOSED: [2024-01-18 Thu]",
        "Task completed"
      ]

      {metadata, remaining} = PropertyDrawer.parse_metadata(lines)

      assert %Org.Timestamp{} = metadata.closed
      assert metadata.closed.type == :inactive
      assert metadata.closed.date == ~D[2024-01-18]
      assert metadata.closed.day_name == "Thu"
      assert remaining == ["Task completed"]
    end

    test "parses multiple metadata lines" do
      lines = [
        "SCHEDULED: <2024-01-15 Mon>",
        "DEADLINE: <2024-01-20 Sat>",
        "CLOSED: [2024-01-18 Thu]",
        "Content after metadata"
      ]

      {metadata, remaining} = PropertyDrawer.parse_metadata(lines)

      assert %Org.Timestamp{} = metadata.scheduled
      assert metadata.scheduled.type == :active
      assert metadata.scheduled.date == ~D[2024-01-15]
      assert metadata.scheduled.day_name == "Mon"

      assert %Org.Timestamp{} = metadata.deadline
      assert metadata.deadline.type == :active
      assert metadata.deadline.date == ~D[2024-01-20]
      assert metadata.deadline.day_name == "Sat"

      assert %Org.Timestamp{} = metadata.closed
      assert metadata.closed.type == :inactive
      assert metadata.closed.date == ~D[2024-01-18]
      assert metadata.closed.day_name == "Thu"

      assert remaining == ["Content after metadata"]
    end

    test "handles metadata with warning periods" do
      lines = [
        "DEADLINE: <2024-01-20 Sat -5d>",
        "SCHEDULED: <2024-01-15 Mon +1w>",
        "Content"
      ]

      {metadata, remaining} = PropertyDrawer.parse_metadata(lines)

      assert %Org.Timestamp{} = metadata.deadline
      assert metadata.deadline.type == :active
      assert metadata.deadline.date == ~D[2024-01-20]
      assert metadata.deadline.day_name == "Sat"
      assert metadata.deadline.warning == %{count: 5, unit: :day}

      assert %Org.Timestamp{} = metadata.scheduled
      assert metadata.scheduled.type == :active
      assert metadata.scheduled.date == ~D[2024-01-15]
      assert metadata.scheduled.day_name == "Mon"
      assert metadata.scheduled.repeater == %{count: 1, unit: :week}

      assert remaining == ["Content"]
    end

    test "handles empty lines" do
      {metadata, remaining} = PropertyDrawer.parse_metadata([])

      assert metadata == %{}
      assert remaining == []
    end

    test "handles non-metadata lines" do
      lines = ["Regular content", "More content"]

      {metadata, remaining} = PropertyDrawer.parse_metadata(lines)

      assert metadata == %{}
      assert remaining == lines
    end
  end

  describe "render_properties/1" do
    test "renders properties to org format" do
      properties = %{
        "ID" => "12345",
        "Author" => "John Doe",
        "Date" => "2024-01-15"
      }

      lines = PropertyDrawer.render_properties(properties)

      assert "  :PROPERTIES:" in lines
      assert "  :Author: John Doe" in lines
      assert "  :Date: 2024-01-15" in lines
      assert "  :ID: 12345" in lines
      assert "  :END:" in lines
    end

    test "renders empty properties as empty list" do
      assert PropertyDrawer.render_properties(%{}) == []
    end

    test "sorts properties alphabetically" do
      properties = %{
        "Zebra" => "value",
        "Alpha" => "value",
        "Middle" => "value"
      }

      lines = PropertyDrawer.render_properties(properties)

      # Remove the PROPERTIES and END lines
      property_lines = Enum.slice(lines, 1..-2//1)

      assert property_lines == [
               "  :Alpha: value",
               "  :Middle: value",
               "  :Zebra: value"
             ]
    end
  end

  describe "render_metadata/1" do
    test "renders metadata to org format" do
      metadata = %{
        scheduled: "<2024-01-15 Mon>",
        deadline: "<2024-01-20 Sat>"
      }

      lines = PropertyDrawer.render_metadata(metadata)

      assert "  SCHEDULED: <2024-01-15 Mon>" in lines
      assert "  DEADLINE: <2024-01-20 Sat>" in lines
    end

    test "renders all metadata types" do
      metadata = %{
        scheduled: "<2024-01-15 Mon>",
        deadline: "<2024-01-20 Sat>",
        closed: "[2024-01-18 Thu]"
      }

      lines = PropertyDrawer.render_metadata(metadata)

      assert length(lines) == 3
      assert "  SCHEDULED: <2024-01-15 Mon>" in lines
      assert "  DEADLINE: <2024-01-20 Sat>" in lines
      assert "  CLOSED: [2024-01-18 Thu]" in lines
    end

    test "renders empty metadata as empty list" do
      assert PropertyDrawer.render_metadata(%{}) == []
    end

    test "preserves metadata order (scheduled, deadline, closed)" do
      metadata = %{
        closed: "[2024-01-18 Thu]",
        scheduled: "<2024-01-15 Mon>",
        deadline: "<2024-01-20 Sat>"
      }

      lines = PropertyDrawer.render_metadata(metadata)

      assert lines == [
               "  SCHEDULED: <2024-01-15 Mon>",
               "  DEADLINE: <2024-01-20 Sat>",
               "  CLOSED: [2024-01-18 Thu]"
             ]
    end
  end

  describe "property_drawer_start?/1" do
    test "identifies property drawer start" do
      assert PropertyDrawer.property_drawer_start?(":PROPERTIES:") == true
      assert PropertyDrawer.property_drawer_start?("  :PROPERTIES:  ") == true
    end

    test "rejects non-property drawer lines" do
      assert PropertyDrawer.property_drawer_start?("PROPERTIES") == false
      assert PropertyDrawer.property_drawer_start?(":END:") == false
      assert PropertyDrawer.property_drawer_start?("Regular line") == false
    end
  end

  describe "metadata_line?/1" do
    test "identifies metadata lines" do
      assert PropertyDrawer.metadata_line?("SCHEDULED: <2024-01-15>") == true
      assert PropertyDrawer.metadata_line?("  DEADLINE: <2024-01-20>  ") == true
      assert PropertyDrawer.metadata_line?("CLOSED: [2024-01-18]") == true
    end

    test "rejects non-metadata lines" do
      assert PropertyDrawer.metadata_line?("Regular content") == false
      assert PropertyDrawer.metadata_line?(":PROPERTIES:") == false
      assert PropertyDrawer.metadata_line?("TODO: Something") == false
    end
  end

  describe "extract_all/1" do
    test "extracts both properties and metadata" do
      lines = [
        ":PROPERTIES:",
        ":ID: 12345",
        ":Priority: High",
        ":END:",
        "SCHEDULED: <2024-01-15 Mon>",
        "DEADLINE: <2024-01-20 Sat>",
        "Regular content starts here"
      ]

      {properties, metadata, remaining} = PropertyDrawer.extract_all(lines)

      assert properties == %{
               "ID" => "12345",
               "Priority" => "High"
             }

      assert %Org.Timestamp{} = metadata.scheduled
      assert metadata.scheduled.type == :active
      assert metadata.scheduled.date == ~D[2024-01-15]
      assert metadata.scheduled.day_name == "Mon"

      assert %Org.Timestamp{} = metadata.deadline
      assert metadata.deadline.type == :active
      assert metadata.deadline.date == ~D[2024-01-20]
      assert metadata.deadline.day_name == "Sat"

      assert remaining == ["Regular content starts here"]
    end

    test "handles properties without metadata" do
      lines = [
        ":PROPERTIES:",
        ":Key: Value",
        ":END:",
        "Content"
      ]

      {properties, metadata, remaining} = PropertyDrawer.extract_all(lines)

      assert properties == %{"Key" => "Value"}
      assert metadata == %{}
      assert remaining == ["Content"]
    end

    test "handles metadata without properties" do
      lines = [
        "SCHEDULED: <2024-01-15 Mon>",
        "Content"
      ]

      {properties, metadata, remaining} = PropertyDrawer.extract_all(lines)

      assert properties == %{}
      assert %Org.Timestamp{} = metadata.scheduled
      assert metadata.scheduled.type == :active
      assert metadata.scheduled.date == ~D[2024-01-15]
      assert metadata.scheduled.day_name == "Mon"
      assert remaining == ["Content"]
    end

    test "handles neither properties nor metadata" do
      lines = ["Just regular content"]

      {properties, metadata, remaining} = PropertyDrawer.extract_all(lines)

      assert properties == %{}
      assert metadata == %{}
      assert remaining == lines
    end

    test "handles complex org-mode section" do
      lines = [
        ":PROPERTIES:",
        ":CUSTOM_ID: my-section",
        ":EXPORT_FILE_NAME: output",
        ":END:",
        "SCHEDULED: <2024-01-15 Mon 10:00>",
        "DEADLINE: <2024-01-20 Sat> ",
        "",
        "This is the actual content of the section.",
        "It can span multiple lines."
      ]

      {properties, metadata, remaining} = PropertyDrawer.extract_all(lines)

      assert properties == %{
               "CUSTOM_ID" => "my-section",
               "EXPORT_FILE_NAME" => "output"
             }

      assert %Org.Timestamp{} = metadata.scheduled
      assert metadata.scheduled.type == :active
      assert metadata.scheduled.date == ~D[2024-01-15]
      assert metadata.scheduled.day_name == "Mon"
      assert metadata.scheduled.start_time == ~T[10:00:00]

      assert %Org.Timestamp{} = metadata.deadline
      assert metadata.deadline.type == :active
      assert metadata.deadline.date == ~D[2024-01-20]
      assert metadata.deadline.day_name == "Sat"

      assert remaining == [
               "",
               "This is the actual content of the section.",
               "It can span multiple lines."
             ]
    end
  end
end
