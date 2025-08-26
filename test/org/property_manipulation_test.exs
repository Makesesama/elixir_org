defmodule Org.PropertyManipulationTest do
  use ExUnit.Case
  doctest Org

  describe "add_property/4" do
    test "adds property to section without existing properties" do
      doc = Org.load_string("* Task")
      doc = Org.add_property(doc, ["Task"], "ID", "12345")

      task = Org.section(doc, ["Task"])
      assert task.properties["ID"] == "12345"
    end

    test "adds property to section with existing properties" do
      doc = Org.load_string("* Task")
      doc = Org.add_property(doc, ["Task"], "ID", "12345")
      doc = Org.add_property(doc, ["Task"], "CATEGORY", "work")

      task = Org.section(doc, ["Task"])
      assert task.properties["ID"] == "12345"
      assert task.properties["CATEGORY"] == "work"
    end

    test "overwrites existing property with same key" do
      doc = Org.load_string("* Task")
      doc = Org.add_property(doc, ["Task"], "ID", "12345")
      doc = Org.add_property(doc, ["Task"], "ID", "67890")

      task = Org.section(doc, ["Task"])
      assert task.properties["ID"] == "67890"
    end

    test "works with nested sections" do
      doc =
        Org.load_string("""
        * Parent
        ** Child
        """)

      doc = Org.add_property(doc, ["Parent", "Child"], "ID", "nested")

      child = Org.section(doc, ["Parent", "Child"])
      assert child.properties["ID"] == "nested"
    end

    test "raises error when trying to add property to non-section" do
      doc = Org.load_string("* Task")

      assert_raise ArgumentError, "Can only add properties to sections", fn ->
        # trying to add to document
        Org.add_property(doc, [], "ID", "12345")
      end
    end
  end

  describe "set_properties/3" do
    test "sets multiple properties on section" do
      doc = Org.load_string("* Task")
      properties = %{"ID" => "12345", "CATEGORY" => "work", "EFFORT" => "2h"}
      doc = Org.set_properties(doc, ["Task"], properties)

      task = Org.section(doc, ["Task"])
      assert task.properties["ID"] == "12345"
      assert task.properties["CATEGORY"] == "work"
      assert task.properties["EFFORT"] == "2h"
    end

    test "replaces all existing properties" do
      doc = Org.load_string("* Task")
      doc = Org.add_property(doc, ["Task"], "OLD", "value")

      new_properties = %{"ID" => "12345", "CATEGORY" => "work"}
      doc = Org.set_properties(doc, ["Task"], new_properties)

      task = Org.section(doc, ["Task"])
      assert task.properties["OLD"] == nil
      assert task.properties["ID"] == "12345"
      assert task.properties["CATEGORY"] == "work"
    end

    test "works with empty properties map" do
      doc = Org.load_string("* Task")
      doc = Org.add_property(doc, ["Task"], "ID", "12345")
      doc = Org.set_properties(doc, ["Task"], %{})

      task = Org.section(doc, ["Task"])
      assert task.properties == %{}
    end
  end

  describe "update_properties/3" do
    test "merges new properties with existing ones" do
      doc = Org.load_string("* Task")
      doc = Org.add_property(doc, ["Task"], "ID", "12345")
      doc = Org.update_properties(doc, ["Task"], %{"CATEGORY" => "work", "EFFORT" => "2h"})

      task = Org.section(doc, ["Task"])
      assert task.properties["ID"] == "12345"
      assert task.properties["CATEGORY"] == "work"
      assert task.properties["EFFORT"] == "2h"
    end

    test "overwrites existing properties with same keys" do
      doc = Org.load_string("* Task")
      doc = Org.add_property(doc, ["Task"], "ID", "12345")
      doc = Org.update_properties(doc, ["Task"], %{"ID" => "67890", "CATEGORY" => "work"})

      task = Org.section(doc, ["Task"])
      assert task.properties["ID"] == "67890"
      assert task.properties["CATEGORY"] == "work"
    end
  end

  describe "remove_property/3" do
    test "removes existing property" do
      doc = Org.load_string("* Task")
      doc = Org.add_property(doc, ["Task"], "ID", "12345")
      doc = Org.add_property(doc, ["Task"], "CATEGORY", "work")
      doc = Org.remove_property(doc, ["Task"], "ID")

      task = Org.section(doc, ["Task"])
      assert task.properties["ID"] == nil
      assert task.properties["CATEGORY"] == "work"
    end

    test "does nothing when property doesn't exist" do
      doc = Org.load_string("* Task")
      doc = Org.add_property(doc, ["Task"], "CATEGORY", "work")
      doc = Org.remove_property(doc, ["Task"], "NONEXISTENT")

      task = Org.section(doc, ["Task"])
      assert task.properties["CATEGORY"] == "work"
    end
  end

  describe "add_metadata/4" do
    test "adds scheduled metadata" do
      doc = Org.load_string("* Task")
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon>")
      doc = Org.add_metadata(doc, ["Task"], :scheduled, timestamp)

      task = Org.section(doc, ["Task"])
      assert task.metadata.scheduled.date == ~D[2024-01-15]
    end

    test "adds deadline metadata" do
      doc = Org.load_string("* Task")
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-20 Sat>")
      doc = Org.add_metadata(doc, ["Task"], :deadline, timestamp)

      task = Org.section(doc, ["Task"])
      assert task.metadata.deadline.date == ~D[2024-01-20]
    end

    test "adds closed metadata" do
      doc = Org.load_string("* Task")
      {:ok, timestamp} = Org.Timestamp.parse("[2024-01-18 Thu]")
      doc = Org.add_metadata(doc, ["Task"], :closed, timestamp)

      task = Org.section(doc, ["Task"])
      assert task.metadata.closed.date == ~D[2024-01-18]
    end

    test "overwrites existing metadata with same key" do
      doc = Org.load_string("* Task")
      {:ok, timestamp1} = Org.Timestamp.parse("<2024-01-15 Mon>")
      {:ok, timestamp2} = Org.Timestamp.parse("<2024-01-16 Tue>")

      doc = Org.add_metadata(doc, ["Task"], :scheduled, timestamp1)
      doc = Org.add_metadata(doc, ["Task"], :scheduled, timestamp2)

      task = Org.section(doc, ["Task"])
      assert task.metadata.scheduled.date == ~D[2024-01-16]
    end

    test "raises error for invalid metadata key" do
      doc = Org.load_string("* Task")
      {:ok, timestamp} = Org.Timestamp.parse("<2024-01-15 Mon>")

      assert_raise FunctionClauseError, fn ->
        Org.add_metadata(doc, ["Task"], :invalid_key, timestamp)
      end
    end
  end

  describe "set_metadata/3" do
    test "sets multiple metadata entries" do
      doc = Org.load_string("* Task")
      {:ok, scheduled} = Org.Timestamp.parse("<2024-01-15 Mon>")
      {:ok, deadline} = Org.Timestamp.parse("<2024-01-20 Sat>")

      metadata = %{scheduled: scheduled, deadline: deadline}
      doc = Org.set_metadata(doc, ["Task"], metadata)

      task = Org.section(doc, ["Task"])
      assert task.metadata.scheduled.date == ~D[2024-01-15]
      assert task.metadata.deadline.date == ~D[2024-01-20]
    end

    test "replaces existing metadata" do
      doc = Org.load_string("* Task")
      {:ok, old_scheduled} = Org.Timestamp.parse("<2024-01-10 Wed>")
      {:ok, deadline} = Org.Timestamp.parse("<2024-01-20 Sat>")

      doc = Org.add_metadata(doc, ["Task"], :scheduled, old_scheduled)
      doc = Org.set_metadata(doc, ["Task"], %{deadline: deadline})

      task = Org.section(doc, ["Task"])
      assert task.metadata[:scheduled] == nil
      assert task.metadata.deadline.date == ~D[2024-01-20]
    end
  end

  describe "update_metadata/3" do
    test "merges new metadata with existing" do
      doc = Org.load_string("* Task")
      {:ok, scheduled} = Org.Timestamp.parse("<2024-01-15 Mon>")
      {:ok, deadline} = Org.Timestamp.parse("<2024-01-20 Sat>")

      doc = Org.add_metadata(doc, ["Task"], :scheduled, scheduled)
      doc = Org.update_metadata(doc, ["Task"], %{deadline: deadline})

      task = Org.section(doc, ["Task"])
      assert task.metadata.scheduled.date == ~D[2024-01-15]
      assert task.metadata.deadline.date == ~D[2024-01-20]
    end

    test "overwrites existing metadata with same key" do
      doc = Org.load_string("* Task")
      {:ok, old_scheduled} = Org.Timestamp.parse("<2024-01-10 Wed>")
      {:ok, new_scheduled} = Org.Timestamp.parse("<2024-01-15 Mon>")

      doc = Org.add_metadata(doc, ["Task"], :scheduled, old_scheduled)
      doc = Org.update_metadata(doc, ["Task"], %{scheduled: new_scheduled})

      task = Org.section(doc, ["Task"])
      assert task.metadata.scheduled.date == ~D[2024-01-15]
    end
  end

  describe "remove_metadata/3" do
    test "removes existing metadata" do
      doc = Org.load_string("* Task")
      {:ok, scheduled} = Org.Timestamp.parse("<2024-01-15 Mon>")
      {:ok, deadline} = Org.Timestamp.parse("<2024-01-20 Sat>")

      doc = Org.add_metadata(doc, ["Task"], :scheduled, scheduled)
      doc = Org.add_metadata(doc, ["Task"], :deadline, deadline)
      doc = Org.remove_metadata(doc, ["Task"], :scheduled)

      task = Org.section(doc, ["Task"])
      assert task.metadata[:scheduled] == nil
      assert task.metadata.deadline.date == ~D[2024-01-20]
    end

    test "does nothing when metadata doesn't exist" do
      doc = Org.load_string("* Task")
      {:ok, scheduled} = Org.Timestamp.parse("<2024-01-15 Mon>")

      doc = Org.add_metadata(doc, ["Task"], :scheduled, scheduled)
      doc = Org.remove_metadata(doc, ["Task"], :deadline)

      task = Org.section(doc, ["Task"])
      assert task.metadata.scheduled.date == ~D[2024-01-15]
      assert task.metadata[:deadline] == nil
    end
  end

  describe "property drawer serialization" do
    test "properties are included in serialized output" do
      doc = Org.load_string("* Task")
      doc = Org.add_property(doc, ["Task"], "ID", "12345")
      doc = Org.add_property(doc, ["Task"], "CATEGORY", "work")

      org_string = Org.to_org_string(doc)

      assert org_string =~ ":PROPERTIES:"
      assert org_string =~ ":ID: 12345"
      assert org_string =~ ":CATEGORY: work"
      assert org_string =~ ":END:"
    end

    test "metadata is included in serialized output" do
      doc = Org.load_string("* Task")
      {:ok, scheduled} = Org.Timestamp.parse("<2024-01-15 Mon>")
      {:ok, deadline} = Org.Timestamp.parse("<2024-01-20 Sat>")

      doc = Org.add_metadata(doc, ["Task"], :scheduled, scheduled)
      doc = Org.add_metadata(doc, ["Task"], :deadline, deadline)

      org_string = Org.to_org_string(doc)

      assert org_string =~ "SCHEDULED: <2024-01-15 Mon>"
      assert org_string =~ "DEADLINE: <2024-01-20 Sat>"
    end

    test "both properties and metadata are serialized together" do
      doc = Org.load_string("* Task")
      {:ok, scheduled} = Org.Timestamp.parse("<2024-01-15 Mon>")

      doc = Org.add_property(doc, ["Task"], "ID", "12345")
      doc = Org.add_metadata(doc, ["Task"], :scheduled, scheduled)

      org_string = Org.to_org_string(doc)

      assert org_string =~ ":PROPERTIES:"
      assert org_string =~ ":ID: 12345"
      assert org_string =~ ":END:"
      assert org_string =~ "SCHEDULED: <2024-01-15 Mon>"
    end
  end

  describe "round-trip parsing and serialization" do
    test "properties survive round-trip" do
      original_org = """
      * Task
        :PROPERTIES:
        :ID: 12345
        :CATEGORY: work
        :END:
      """

      doc = Org.load_string(original_org)
      doc = Org.add_property(doc, ["Task"], "EFFORT", "2h")

      serialized = Org.to_org_string(doc)
      reparsed_doc = Org.load_string(serialized)

      task = Org.section(reparsed_doc, ["Task"])
      assert task.properties["ID"] == "12345"
      assert task.properties["CATEGORY"] == "work"
      assert task.properties["EFFORT"] == "2h"
    end

    test "metadata survives round-trip" do
      original_org = """
      * Task
        SCHEDULED: <2024-01-15 Mon>
        DEADLINE: <2024-01-20 Sat>
      """

      doc = Org.load_string(original_org)
      {:ok, closed} = Org.Timestamp.parse("[2024-01-18 Thu]")
      doc = Org.add_metadata(doc, ["Task"], :closed, closed)

      serialized = Org.to_org_string(doc)
      reparsed_doc = Org.load_string(serialized)

      task = Org.section(reparsed_doc, ["Task"])
      assert task.metadata.scheduled.date == ~D[2024-01-15]
      assert task.metadata.deadline.date == ~D[2024-01-20]
      assert task.metadata.closed.date == ~D[2024-01-18]
    end
  end
end
