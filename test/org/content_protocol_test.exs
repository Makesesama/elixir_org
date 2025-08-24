defmodule Org.ContentProtocolTest do
  use ExUnit.Case

  alias Org.Content
  alias Org.ContentBuilder

  describe "Paragraph content protocol" do
    test "content type identification" do
      paragraph = %Org.Paragraph{lines: ["Hello", "World"]}
      assert Content.content_type(paragraph) == :paragraph
    end

    test "reverse recursive" do
      paragraph = %Org.Paragraph{lines: ["Third", "Second", "First"]}
      reversed = Content.reverse_recursive(paragraph)

      assert reversed.lines == ["First", "Second", "Third"]
    end

    test "cannot merge with other paragraphs" do
      p1 = %Org.Paragraph{lines: ["First"]}
      p2 = %Org.Paragraph{lines: ["Second"]}

      # Paragraphs are kept separate to preserve structure
      assert Content.can_merge?(p1, p2) == false
      assert Content.can_merge?(p1, %Org.Table{rows: []}) == false
    end

    test "merge paragraphs (when forced)" do
      p1 = %Org.Paragraph{lines: ["First line"]}
      p2 = %Org.Paragraph{lines: ["Second line"]}

      # Even though paragraphs don't auto-merge, the merge function should still work when called directly
      merged = Content.merge(p1, p2)
      assert merged.lines == ["First line", "", "Second line"]
    end

    test "validation" do
      valid_para = %Org.Paragraph{lines: ["Hello", "World"]}
      assert Content.validate(valid_para) == {:ok, valid_para}

      invalid_para = %Org.Paragraph{lines: ["Hello", 123]}
      assert {:error, _reason} = Content.validate(invalid_para)
    end

    test "to_text conversion" do
      paragraph = %Org.Paragraph{lines: ["Hello", "World"]}
      assert Content.to_text(paragraph) == "Hello\nWorld"
    end

    test "metadata extraction" do
      paragraph = %Org.Paragraph{lines: ["Hello world", "How are you?"]}
      metadata = Content.metadata(paragraph)

      assert metadata.line_count == 2
      assert metadata.word_count == 5
      assert metadata.character_count > 0
    end

    test "empty detection" do
      empty_para = %Org.Paragraph{lines: []}
      assert Content.empty?(empty_para) == true

      whitespace_para = %Org.Paragraph{lines: ["   ", "\t", ""]}
      assert Content.empty?(whitespace_para) == true

      content_para = %Org.Paragraph{lines: ["Hello"]}
      assert Content.empty?(content_para) == false
    end
  end

  describe "Table content protocol" do
    test "content type and basic operations" do
      table = %Org.Table{rows: [%Org.Table.Row{cells: ["A", "B"]}]}

      assert Content.content_type(table) == :table
      assert Content.can_merge?(table, %Org.Table{rows: []}) == true
      assert Content.empty?(%Org.Table{rows: []}) == true
    end

    test "table merging" do
      t1 = %Org.Table{rows: [%Org.Table.Row{cells: ["A", "B"]}]}
      t2 = %Org.Table{rows: [%Org.Table.Row{cells: ["C", "D"]}]}

      merged = Content.merge(t1, t2)
      assert length(merged.rows) == 2
    end

    test "table metadata" do
      table = %Org.Table{
        rows: [
          %Org.Table.Row{cells: ["A", "B", "C"]},
          %Org.Table.Separator{},
          %Org.Table.Row{cells: ["D", "E"]}
        ]
      }

      metadata = Content.metadata(table)
      assert metadata.total_rows == 3
      assert metadata.data_rows == 2
      assert metadata.separator_rows == 1
      assert metadata.max_columns == 3
    end
  end

  describe "List content protocol" do
    test "content type and basic operations" do
      list = %Org.List{items: [%Org.List.Item{content: "Test", indent: 0, ordered: false}]}

      assert Content.content_type(list) == :list
      assert Content.can_merge?(list, %Org.List{items: []}) == true
    end

    test "list metadata with nesting" do
      nested_list = %Org.List{
        items: [
          %Org.List.Item{
            content: "Top",
            indent: 0,
            ordered: false,
            children: [
              %Org.List.Item{content: "Nested", indent: 2, ordered: false, children: []}
            ]
          }
        ]
      }

      metadata = Content.metadata(nested_list)
      assert metadata.total_items == 2
      assert metadata.top_level_items == 1
      # 0-indexed depth
      assert metadata.max_depth == 1
    end
  end

  describe "CodeBlock content protocol" do
    test "content type and operations" do
      code_block = %Org.CodeBlock{lang: "elixir", details: "", lines: ["IO.puts(\"hello\")"]}

      assert Content.content_type(code_block) == :code_block
      assert Content.can_merge?(code_block, %Org.CodeBlock{}) == false
    end

    test "code block metadata" do
      code_block = %Org.CodeBlock{
        lang: "python",
        details: "-n 10",
        lines: ["def hello():", "    print('world')"]
      }

      metadata = Content.metadata(code_block)
      assert metadata.language == "python"
      assert metadata.details == "-n 10"
      assert metadata.line_count == 2
    end
  end

  describe "ContentBuilder" do
    test "handles text line creation" do
      result = ContentBuilder.handle_content([], {:text, "Hello world"}, %{mode: :normal})

      assert {:handled, [%Org.Paragraph{lines: ["Hello world"]}], :paragraph} = result
    end

    test "handles text line extension" do
      existing_para = %Org.Paragraph{lines: ["First line"]}
      result = ContentBuilder.handle_content([existing_para], {:text, "Second line"}, %{mode: :paragraph})

      assert {:handled, [%Org.Paragraph{lines: ["Second line", "First line"]}], :paragraph} = result
    end

    test "handles table row creation" do
      result = ContentBuilder.handle_content([], {:table_row, ["A", "B", "C"]}, %{mode: :normal})

      assert {:handled, [%Org.Table{}], :table} = result
    end

    test "handles list item creation" do
      result = ContentBuilder.handle_content([], {:list_item, 0, false, nil, "Item 1"}, %{mode: :normal})

      assert {:handled, [%Org.List{items: [%Org.List.Item{content: "Item 1"}]}], :list} = result
    end

    test "keeps separate paragraphs separate" do
      p1 = %Org.Paragraph{lines: ["First"]}
      p2 = %Org.Paragraph{lines: ["Second"]}
      # Note: reversed order as parser builds
      content_list = [p2, p1]

      merged = ContentBuilder.merge_compatible_content(content_list)

      # Paragraphs should remain separate
      assert length(merged) == 2
      assert [%Org.Paragraph{lines: ["Second"]}, %Org.Paragraph{lines: ["First"]}] = merged
    end

    test "validates content list" do
      valid_content = [
        %Org.Paragraph{lines: ["Hello"]},
        %Org.Table{rows: [%Org.Table.Row{cells: ["A"]}]}
      ]

      assert {:ok, _} = ContentBuilder.validate_content_list(valid_content)
    end
  end

  describe "Error handling and edge cases" do
    test "handles invalid content gracefully" do
      invalid_para = %Org.Paragraph{lines: ["Valid", 123, "Mixed"]}
      assert {:error, _} = Content.validate(invalid_para)
    end

    test "empty line handling ends modes appropriately" do
      context = %{mode: :paragraph}
      result = ContentBuilder.handle_content([], {:empty_line}, context)

      # Should transition to normal mode
      assert {:handled, [], :normal} = result
    end

    test "unknown content types return appropriate defaults" do
      unknown = %{some: "unknown struct"}

      assert Content.content_type(unknown) == :unknown
      assert Content.empty?(unknown) == true
      assert Content.to_text(unknown) == ""
    end
  end

  describe "Integration with real parsing scenarios" do
    test "handles mixed content document" do
      # This would be called by the parser with real tokens
      tokens = [
        {:text, "First paragraph"},
        {:empty_line},
        {:table_row, ["Header1", "Header2"]},
        {:table_row, ["Data1", "Data2"]},
        {:empty_line},
        {:list_item, 0, false, nil, "List item"}
      ]

      # Simulate parser behavior
      content_list = []
      context = %{mode: :normal}

      {final_content, _final_context} =
        Enum.reduce(tokens, {content_list, context}, fn token, {current_content, current_context} ->
          case ContentBuilder.handle_content(current_content, token, current_context) do
            {:handled, new_content, new_mode} ->
              {new_content, %{current_context | mode: new_mode}}

            {:unhandled, content} ->
              {content, current_context}

            {:error, _reason} ->
              {current_content, current_context}
          end
        end)

      # Should have created separate content elements
      # paragraph, table, list
      assert length(final_content) >= 3

      # Verify content types
      content_types = Enum.map(final_content, &Content.content_type/1)
      assert :paragraph in content_types
      assert :table in content_types
      assert :list in content_types
    end
  end
end
