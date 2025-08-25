defmodule Org.NodeFinderTest do
  use ExUnit.Case

  alias Org.{Document, NodeFinder, Paragraph, Section}

  setup do
    doc = %Document{
      sections: [
        %Section{
          title: "Parent1",
          todo_keyword: "TODO",
          priority: "A",
          contents: [
            %Paragraph{lines: ["Parent1 content"]}
          ],
          children: [
            %Section{
              title: "Child1",
              todo_keyword: "DONE",
              children: [
                %Section{title: "Grandchild1", children: [], contents: []}
              ],
              contents: []
            },
            %Section{
              title: "Child2",
              children: [],
              contents: [
                %Paragraph{lines: ["Child2 content"]}
              ]
            }
          ]
        },
        %Section{
          title: "Parent2",
          children: [],
          contents: []
        }
      ],
      contents: [
        %Paragraph{lines: ["Document content"]}
      ]
    }

    {:ok, doc: doc}
  end

  describe "find_by_path/2" do
    test "finds document root with empty path", %{doc: doc} do
      result = NodeFinder.find_by_path(doc, [])
      assert result == doc
    end

    test "finds top-level section by title", %{doc: doc} do
      result = NodeFinder.find_by_path(doc, ["Parent1"])
      assert result.title == "Parent1"
      assert result.todo_keyword == "TODO"
    end

    test "finds nested section by path", %{doc: doc} do
      result = NodeFinder.find_by_path(doc, ["Parent1", "Child1"])
      assert result.title == "Child1"
      assert result.todo_keyword == "DONE"
    end

    test "finds deeply nested section", %{doc: doc} do
      result = NodeFinder.find_by_path(doc, ["Parent1", "Child1", "Grandchild1"])
      assert result.title == "Grandchild1"
    end

    test "returns nil for non-existent path", %{doc: doc} do
      result = NodeFinder.find_by_path(doc, ["NonExistent"])
      assert result == nil

      result = NodeFinder.find_by_path(doc, ["Parent1", "NonExistent"])
      assert result == nil
    end

    test "finds section by index", %{doc: doc} do
      result = NodeFinder.find_by_path(doc, [{:section, 0}])
      assert result.title == "Parent1"

      result = NodeFinder.find_by_path(doc, [{:section, 1}])
      assert result.title == "Parent2"
    end

    test "finds content by index", %{doc: doc} do
      result = NodeFinder.find_by_path(doc, [{:content, 0}])
      assert %Paragraph{} = result
      assert result.lines == ["Document content"]
    end

    test "finds nested child by index", %{doc: doc} do
      result = NodeFinder.find_by_path(doc, ["Parent1", {:child, 0}])
      assert result.title == "Child1"

      result = NodeFinder.find_by_path(doc, ["Parent1", {:child, 1}])
      assert result.title == "Child2"
    end
  end

  describe "find_all/2" do
    test "finds all sections with TODO keyword", %{doc: doc} do
      results =
        NodeFinder.find_all(doc, fn
          %Section{todo_keyword: "TODO"} -> true
          _ -> false
        end)

      assert length(results) == 1
      assert hd(results).title == "Parent1"
    end

    test "finds all sections with DONE keyword", %{doc: doc} do
      results =
        NodeFinder.find_all(doc, fn
          %Section{todo_keyword: "DONE"} -> true
          _ -> false
        end)

      assert length(results) == 1
      assert hd(results).title == "Child1"
    end

    test "finds all paragraphs", %{doc: doc} do
      results =
        NodeFinder.find_all(doc, fn
          %Paragraph{} -> true
          _ -> false
        end)

      assert length(results) == 3
    end

    test "finds sections with specific priority", %{doc: doc} do
      results =
        NodeFinder.find_all(doc, fn
          %Section{priority: "A"} -> true
          _ -> false
        end)

      assert length(results) == 1
      assert hd(results).priority == "A"
    end

    test "finds all leaf sections (no children)", %{doc: doc} do
      results =
        NodeFinder.find_all(doc, fn
          %Section{children: []} -> true
          _ -> false
        end)

      titles = Enum.map(results, & &1.title)
      assert "Grandchild1" in titles
      assert "Child2" in titles
      assert "Parent2" in titles
      assert length(results) == 3
    end
  end

  describe "find_parent/2" do
    test "finds parent of top-level section", %{doc: doc} do
      section = NodeFinder.find_by_path(doc, ["Parent1"])
      {parent, {type, index}} = NodeFinder.find_parent(doc, section)

      assert parent == doc
      assert type == :section
      assert index == 0
    end

    test "finds parent of nested section", %{doc: doc} do
      child = NodeFinder.find_by_path(doc, ["Parent1", "Child1"])
      {parent, {type, index}} = NodeFinder.find_parent(doc, child)

      assert parent.title == "Parent1"
      assert type == :child
      assert index == 0
    end

    test "finds parent of content in section", %{doc: doc} do
      section = NodeFinder.find_by_path(doc, ["Parent1", "Child2"])
      content = hd(section.contents)

      {parent, {type, index}} = NodeFinder.find_parent(doc, content)

      assert parent.title == "Child2"
      assert type == :content
      assert index == 0
    end

    test "finds parent of document content", %{doc: doc} do
      content = hd(doc.contents)
      {parent, {type, index}} = NodeFinder.find_parent(doc, content)

      assert parent == doc
      assert type == :content
      assert index == 0
    end
  end

  describe "path_to_node/2" do
    test "generates path to top-level section", %{doc: doc} do
      section = NodeFinder.find_by_path(doc, ["Parent1"])
      path = NodeFinder.path_to_node(doc, section)

      assert path == ["Parent1"]
    end

    test "generates path to nested section", %{doc: doc} do
      child = NodeFinder.find_by_path(doc, ["Parent1", "Child2"])
      path = NodeFinder.path_to_node(doc, child)

      assert path == ["Parent1", "Child2"]
    end

    test "generates path to deeply nested section", %{doc: doc} do
      grandchild = NodeFinder.find_by_path(doc, ["Parent1", "Child1", "Grandchild1"])
      path = NodeFinder.path_to_node(doc, grandchild)

      assert path == ["Parent1", "Child1", "Grandchild1"]
    end

    test "returns nil for node not in document", %{doc: doc} do
      orphan = %Section{title: "Orphan", children: [], contents: []}
      path = NodeFinder.path_to_node(doc, orphan)

      assert path == nil
    end
  end

  describe "walk/2" do
    test "walks all nodes in document", %{doc: doc} do
      _nodes = []

      NodeFinder.walk(doc, fn node, path ->
        send(self(), {:node, node, path})
      end)

      messages = collect_messages([])

      # Check we visited the document
      assert Enum.any?(messages, fn {:node, node, _path} ->
               match?(%Document{}, node)
             end)

      # Check we visited all sections
      section_visits =
        Enum.filter(messages, fn {:node, node, _path} ->
          match?(%Section{}, node)
        end)

      # Parent1, Child1, Child2, Grandchild1, Parent2
      assert length(section_visits) == 5
    end

    test "provides correct paths during walk", %{doc: doc} do
      _paths_map = %{}

      NodeFinder.walk(doc, fn
        %Section{title: title}, path ->
          send(self(), {title, path})

        _, _ ->
          :ok
      end)

      messages = collect_messages([])

      assert {"Parent1", ["Parent1"]} in messages
      assert {"Child1", ["Parent1", "Child1"]} in messages
      assert {"Child2", ["Parent1", "Child2"]} in messages
      assert {"Grandchild1", ["Parent1", "Child1", "Grandchild1"]} in messages
      assert {"Parent2", ["Parent2"]} in messages
    end
  end

  # Helper to collect messages from process mailbox
  defp collect_messages(acc) do
    receive do
      msg -> collect_messages([msg | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
