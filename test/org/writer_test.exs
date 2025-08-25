defmodule Org.WriterTest do
  use ExUnit.Case

  alias Org.{CodeBlock, Document, List, NodeFinder, Paragraph, Section, Table, Writer}

  describe "add_section/5" do
    test "adds section to document root" do
      doc = %Document{}
      doc = Writer.add_section(doc, [], "New Section", "TODO", "A")

      assert length(doc.sections) == 1
      section = hd(doc.sections)
      assert section.title == "New Section"
      assert section.todo_keyword == "TODO"
      assert section.priority == "A"
    end

    test "adds child section under existing section" do
      doc = %Document{
        sections: [%Section{title: "Parent", children: [], contents: []}]
      }

      doc = Writer.add_section(doc, ["Parent"], "Child", "DONE", "B")

      parent = NodeFinder.find_by_path(doc, ["Parent"])
      assert length(parent.children) == 1
      child = hd(parent.children)
      assert child.title == "Child"
      assert child.todo_keyword == "DONE"
      assert child.priority == "B"
    end

    test "adds deeply nested section" do
      doc = Org.Parser.parse("* Level1\n** Level2")
      doc = Writer.add_section(doc, ["Level1", "Level2"], "Level3")

      level3 = NodeFinder.find_by_path(doc, ["Level1", "Level2", "Level3"])
      assert level3 != nil
      assert level3.title == "Level3"
    end
  end

  describe "add_content/3" do
    test "adds content to document root" do
      doc = %Document{}
      para = %Paragraph{lines: ["Test content"]}
      doc = Writer.add_content(doc, [], para)

      assert length(doc.contents) == 1
      assert hd(doc.contents) == para
    end

    test "adds content to section" do
      doc = %Document{
        sections: [%Section{title: "Section", children: [], contents: []}]
      }

      para = %Paragraph{lines: ["Section content"]}
      doc = Writer.add_content(doc, ["Section"], para)

      section = NodeFinder.find_by_path(doc, ["Section"])
      assert length(section.contents) == 1
      assert hd(section.contents) == para
    end

    test "adds multiple content types" do
      doc = Org.Parser.parse("* Section")

      # Add paragraph
      para = %Paragraph{lines: ["Paragraph"]}
      doc = Writer.add_content(doc, ["Section"], para)

      # Add code block
      code = %CodeBlock{lang: "elixir", details: "", lines: ["IO.puts"]}
      doc = Writer.add_content(doc, ["Section"], code)

      # Add table
      table = %Table{rows: [%Table.Row{cells: ["A", "B"]}]}
      doc = Writer.add_content(doc, ["Section"], table)

      section = NodeFinder.find_by_path(doc, ["Section"])
      assert length(section.contents) == 3
    end
  end

  describe "insert_section/6" do
    test "inserts at first position" do
      doc = Org.Parser.parse("* A\n* B\n* C")
      doc = Writer.insert_section(doc, [], :first, "First")

      titles = Enum.map(doc.sections, & &1.title)
      assert titles == ["First", "A", "B", "C"]
    end

    test "inserts at last position" do
      doc = Org.Parser.parse("* A\n* B")
      doc = Writer.insert_section(doc, [], :last, "Last")

      titles = Enum.map(doc.sections, & &1.title)
      assert titles == ["A", "B", "Last"]
    end

    test "inserts before specific section" do
      doc = Org.Parser.parse("* A\n* B\n* C")
      doc = Writer.insert_section(doc, [], {:before, "B"}, "BeforeB")

      titles = Enum.map(doc.sections, & &1.title)
      assert titles == ["A", "BeforeB", "B", "C"]
    end

    test "inserts after specific section" do
      doc = Org.Parser.parse("* A\n* B\n* C")
      doc = Writer.insert_section(doc, [], {:after, "B"}, "AfterB")

      titles = Enum.map(doc.sections, & &1.title)
      assert titles == ["A", "B", "AfterB", "C"]
    end

    test "inserts at numeric index" do
      doc = Org.Parser.parse("* A\n* B\n* C")
      doc = Writer.insert_section(doc, [], 1, "AtIndex1")

      titles = Enum.map(doc.sections, & &1.title)
      assert titles == ["A", "AtIndex1", "B", "C"]
    end
  end

  describe "update_node/3" do
    test "updates section properties" do
      doc = Org.Parser.parse("* Original")

      doc =
        Writer.update_node(doc, ["Original"], fn section ->
          %{section | title: "Updated", todo_keyword: "TODO", priority: "A"}
        end)

      section = hd(doc.sections)
      assert section.title == "Updated"
      assert section.todo_keyword == "TODO"
      assert section.priority == "A"
    end

    test "updates nested section" do
      doc = Org.Parser.parse("* Parent\n** Child")

      doc =
        Writer.update_node(doc, ["Parent", "Child"], fn section ->
          %{section | todo_keyword: "DONE"}
        end)

      child = NodeFinder.find_by_path(doc, ["Parent", "Child"])
      assert child.todo_keyword == "DONE"
    end
  end

  describe "remove_node/2" do
    test "removes top-level section" do
      doc = Org.Parser.parse("* A\n* B\n* C")
      doc = Writer.remove_node(doc, ["B"])

      titles = Enum.map(doc.sections, & &1.title)
      assert titles == ["A", "C"]
    end

    test "removes nested section" do
      doc = Org.Parser.parse("* Parent\n** Child1\n** Child2")
      doc = Writer.remove_node(doc, ["Parent", "Child1"])

      parent = NodeFinder.find_by_path(doc, ["Parent"])
      assert length(parent.children) == 1
      assert hd(parent.children).title == "Child2"
    end
  end

  describe "move_node/3" do
    test "moves section to different parent" do
      doc = Org.Parser.parse("* A\n** Child\n* B")
      doc = Writer.move_node(doc, ["A", "Child"], ["B"])

      # Child should be removed from A
      a = NodeFinder.find_by_path(doc, ["A"])
      assert Enum.empty?(a.children)

      # Child should be under B
      child = NodeFinder.find_by_path(doc, ["B", "Child"])
      assert child != nil
      assert child.title == "Child"
    end

    test "moves section to root" do
      doc = Org.Parser.parse("* Parent\n** Child")
      doc = Writer.move_node(doc, ["Parent", "Child"], [])

      # Should now have two root sections
      assert length(doc.sections) == 2
      titles = Enum.map(doc.sections, & &1.title)
      assert "Child" in titles
    end
  end

  describe "to_org_string/1" do
    test "serializes simple document" do
      doc = %Document{
        comments: ["+TITLE: Test"],
        sections: [
          %Section{
            title: "Section",
            todo_keyword: "TODO",
            priority: "A",
            children: [],
            contents: [%Paragraph{lines: ["Content"]}]
          }
        ]
      }

      org_string = Writer.to_org_string(doc)

      assert org_string =~ "#+TITLE: Test"
      assert org_string =~ "* TODO [#A] Section"
      assert org_string =~ "Content"
    end

    test "serializes nested sections" do
      doc = %Document{
        sections: [
          %Section{
            title: "Parent",
            children: [
              %Section{
                title: "Child",
                children: [
                  %Section{title: "Grandchild", children: [], contents: []}
                ],
                contents: []
              }
            ],
            contents: []
          }
        ]
      }

      org_string = Writer.to_org_string(doc)

      assert org_string =~ "* Parent"
      assert org_string =~ "** Child"
      assert org_string =~ "*** Grandchild"
    end

    test "serializes code blocks" do
      doc = %Document{
        contents: [
          %CodeBlock{
            lang: "elixir",
            details: "-n",
            lines: ["defmodule Test do", "  def hello, do: :world", "end"]
          }
        ]
      }

      org_string = Writer.to_org_string(doc)

      assert org_string =~ "#+BEGIN_SRC elixir -n"
      assert org_string =~ "defmodule Test do"
      assert org_string =~ "#+END_SRC"
    end

    test "serializes tables" do
      doc = %Document{
        contents: [
          %Table{
            rows: [
              %Table.Row{cells: ["Name", "Value"]},
              %Table.Separator{},
              %Table.Row{cells: ["Foo", "42"]}
            ]
          }
        ]
      }

      org_string = Writer.to_org_string(doc)

      assert org_string =~ "| Name | Value |"
      assert org_string =~ "|----------|"
      assert org_string =~ "| Foo | 42 |"
    end

    test "serializes lists" do
      doc = %Document{
        contents: [
          %List{
            items: [
              %List.Item{
                content: "First",
                indent: 0,
                ordered: false,
                children: [
                  %List.Item{
                    content: "Nested",
                    indent: 2,
                    ordered: false,
                    children: []
                  }
                ]
              },
              %List.Item{
                content: "Second",
                indent: 0,
                ordered: true,
                number: 1,
                children: []
              }
            ]
          }
        ]
      }

      org_string = Writer.to_org_string(doc)

      assert org_string =~ "- First"
      assert org_string =~ "    - Nested"
      assert org_string =~ "1. Second"
    end

    test "round-trip: parse, modify, and serialize" do
      original = """
      * TODO [#A] Main Task
      This is the main task description.

      ** DONE Subtask
      Completed subtask.

      * Another Section
      With some content.
      """

      doc = Org.Parser.parse(original)

      # Add a new section
      doc = Writer.add_section(doc, ["Main Task"], "New Subtask", "TODO", "B")

      # Add content to the new section
      para = %Paragraph{lines: ["New subtask content"]}
      doc = Writer.add_content(doc, ["Main Task", "New Subtask"], para)

      # Serialize back
      result = Writer.to_org_string(doc)

      # Check that original content is preserved
      assert result =~ "* TODO [#A] Main Task"
      assert result =~ "This is the main task description"
      assert result =~ "** DONE Subtask"
      assert result =~ "* Another Section"

      # Check that new content is added
      assert result =~ "** TODO [#B] New Subtask"
      assert result =~ "New subtask content"
    end
  end
end
