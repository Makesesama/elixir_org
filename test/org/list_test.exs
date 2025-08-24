defmodule Org.ListTest do
  use ExUnit.Case
  doctest Org.List

  describe "list parsing" do
    test "parses simple unordered list" do
      source = "- First item\n- Second item"
      doc = Org.Parser.parse(source)
      [list] = Org.lists(doc)

      assert length(list.items) == 2
      assert Enum.at(list.items, 0).content == "First item"
      assert Enum.at(list.items, 0).ordered == false
      assert Enum.at(list.items, 1).content == "Second item"
      assert Enum.at(list.items, 1).ordered == false
    end

    test "parses simple ordered list" do
      source = "1. First item\n2. Second item"
      doc = Org.Parser.parse(source)
      [list] = Org.lists(doc)

      assert length(list.items) == 2
      assert Enum.at(list.items, 0).content == "First item"
      assert Enum.at(list.items, 0).ordered == true
      assert Enum.at(list.items, 0).number == 1
      assert Enum.at(list.items, 1).content == "Second item"
      assert Enum.at(list.items, 1).ordered == true
      assert Enum.at(list.items, 1).number == 2
    end

    test "parses mixed list with different bullet styles" do
      source = "- Dash bullet\n+ Plus bullet"
      doc = Org.Parser.parse(source)
      [list] = Org.lists(doc)

      assert length(list.items) == 2
      assert Enum.at(list.items, 0).content == "Dash bullet"
      assert Enum.at(list.items, 1).content == "Plus bullet"
      Enum.each(list.items, fn item -> assert item.ordered == false end)
    end

    test "parses ordered list with parentheses" do
      source = "1) First item\n2) Second item"
      doc = Org.Parser.parse(source)
      [list] = Org.lists(doc)

      assert length(list.items) == 2
      assert Enum.at(list.items, 0).content == "First item"
      assert Enum.at(list.items, 0).number == 1
      assert Enum.at(list.items, 1).content == "Second item"
      assert Enum.at(list.items, 1).number == 2
    end

    test "parses nested lists" do
      source = """
      - Top level item
        - Nested item 1
        - Nested item 2
      - Another top level
      """

      doc = Org.Parser.parse(source)
      [list] = Org.lists(doc)

      # Should parse as flat list initially, nesting handled by build_nested
      assert length(list.items) == 4

      # Test indentation levels
      assert Enum.at(list.items, 0).indent == 0
      assert Enum.at(list.items, 1).indent == 2
      assert Enum.at(list.items, 2).indent == 2
      assert Enum.at(list.items, 3).indent == 0
    end

    test "handles mixed ordered and unordered in same list" do
      source = """
      - Unordered item
      1. Ordered item
      - Another unordered
      2. Another ordered
      """

      doc = Org.Parser.parse(source)
      [list] = Org.lists(doc)

      assert length(list.items) == 4
      assert Enum.at(list.items, 0).ordered == false
      assert Enum.at(list.items, 1).ordered == true
      assert Enum.at(list.items, 2).ordered == false
      assert Enum.at(list.items, 3).ordered == true
    end
  end

  describe "lexer tokenization" do
    test "tokenizes unordered list items" do
      tokens = Org.Lexer.lex("- First item\n+ Second item")

      assert tokens == [
               {:list_item, 0, false, nil, "First item"},
               {:list_item, 0, false, nil, "Second item"}
             ]
    end

    test "tokenizes ordered list items with dots" do
      tokens = Org.Lexer.lex("1. First item\n2. Second item")

      assert tokens == [
               {:list_item, 0, true, 1, "First item"},
               {:list_item, 0, true, 2, "Second item"}
             ]
    end

    test "tokenizes ordered list items with parentheses" do
      tokens = Org.Lexer.lex("1) First item\n2) Second item")

      assert tokens == [
               {:list_item, 0, true, 1, "First item"},
               {:list_item, 0, true, 2, "Second item"}
             ]
    end

    test "tokenizes indented list items" do
      tokens = Org.Lexer.lex("- Top\n  - Nested\n    - Deep nested")

      assert tokens == [
               {:list_item, 0, false, nil, "Top"},
               {:list_item, 2, false, nil, "Nested"},
               {:list_item, 4, false, nil, "Deep nested"}
             ]
    end
  end

  describe "list building" do
    test "builds nested structure from flat list" do
      items = [
        %Org.List.Item{content: "Top", indent: 0, ordered: false},
        %Org.List.Item{content: "Nested 1", indent: 2, ordered: false},
        %Org.List.Item{content: "Nested 2", indent: 2, ordered: false},
        %Org.List.Item{content: "Another top", indent: 0, ordered: false}
      ]

      nested = Org.List.build_nested(items)

      assert length(nested) == 2
      assert Enum.at(nested, 0).content == "Top"
      assert length(Enum.at(nested, 0).children) == 2
      assert Enum.at(Enum.at(nested, 0).children, 0).content == "Nested 1"
      assert Enum.at(Enum.at(nested, 0).children, 1).content == "Nested 2"
      assert Enum.at(nested, 1).content == "Another top"
      assert Enum.empty?(Enum.at(nested, 1).children)
    end
  end

  describe "content protocol" do
    test "reverses list items correctly" do
      list = %Org.List{
        items: [
          %Org.List.Item{content: "Third", children: []},
          %Org.List.Item{content: "Second", children: []},
          %Org.List.Item{content: "First", children: []}
        ]
      }

      reversed = Org.Content.reverse_recursive(list)

      assert length(reversed.items) == 3
      assert Enum.at(reversed.items, 0).content == "First"
      assert Enum.at(reversed.items, 1).content == "Second"
      assert Enum.at(reversed.items, 2).content == "Third"
    end
  end
end
