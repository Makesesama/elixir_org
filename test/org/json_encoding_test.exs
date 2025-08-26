defmodule Org.JSONEncodingTest do
  use ExUnit.Case

  describe "JSON encoding" do
    test "encodes a simple document" do
      doc = %Org.Document{
        comments: ["# This is a comment"],
        sections: [],
        contents: [
          %Org.Paragraph{lines: ["Hello world"]}
        ]
      }

      json_map = Org.JSONEncodable.to_json_map(doc)

      assert json_map == %{
               type: "document",
               comments: ["# This is a comment"],
               file_properties: %{},
               sections: [],
               contents: [
                 %{
                   type: "paragraph",
                   lines: ["Hello world"]
                 }
               ]
             }
    end

    test "encodes formatted text" do
      formatted = %Org.FormattedText{
        spans: [
          "This is ",
          %Org.FormattedText.Span{format: :bold, content: "bold"},
          " and ",
          %Org.FormattedText.Span{format: :italic, content: "italic"},
          " text"
        ]
      }

      json_map = Org.JSONEncodable.to_json_map(formatted)

      assert json_map == %{
               type: "formatted_text",
               spans: [
                 "This is ",
                 %{type: "span", format: :bold, content: "bold"},
                 " and ",
                 %{type: "span", format: :italic, content: "italic"},
                 " text"
               ]
             }
    end

    test "encodes sections with TODO and priority" do
      section = %Org.Section{
        title: "Important Task",
        todo_keyword: "TODO",
        priority: "A",
        children: [],
        contents: [
          %Org.Paragraph{lines: ["Task description"]}
        ]
      }

      json_map = Org.JSONEncodable.to_json_map(section)

      assert json_map == %{
               type: "section",
               title: "Important Task",
               todo_keyword: "TODO",
               priority: "A",
               children: [],
               contents: [
                 %{type: "paragraph", lines: ["Task description"]}
               ]
             }
    end

    test "encodes lists with nested items" do
      list = %Org.List{
        items: [
          %Org.List.Item{
            content: "First item",
            indent: 0,
            ordered: false,
            number: nil,
            children: [
              %Org.List.Item{
                content: "Nested item",
                indent: 2,
                ordered: false,
                number: nil,
                children: []
              }
            ]
          },
          %Org.List.Item{
            content: "Second item",
            indent: 0,
            ordered: true,
            number: 1,
            children: []
          }
        ]
      }

      json_map = Org.JSONEncodable.to_json_map(list)

      assert json_map.type == "list"
      assert length(json_map.items) == 2
      assert List.first(json_map.items).content == "First item"
      assert length(List.first(json_map.items).children) == 1
    end

    test "encodes tables" do
      table = %Org.Table{
        rows: [
          %Org.Table.Row{cells: ["Header 1", "Header 2"]},
          %Org.Table.Separator{},
          %Org.Table.Row{cells: ["Data 1", "Data 2"]}
        ]
      }

      json_map = Org.JSONEncodable.to_json_map(table)

      assert json_map == %{
               type: "table",
               rows: [
                 %{type: "table_row", cells: ["Header 1", "Header 2"]},
                 %{type: "table_separator"},
                 %{type: "table_row", cells: ["Data 1", "Data 2"]}
               ]
             }
    end

    test "encodes code blocks" do
      code_block = %Org.CodeBlock{
        lang: "elixir",
        details: "-n",
        lines: ["defmodule Example do", "  def hello, do: :world", "end"]
      }

      json_map = Org.JSONEncodable.to_json_map(code_block)

      assert json_map == %{
               type: "code_block",
               lang: "elixir",
               details: "-n",
               lines: ["defmodule Example do", "  def hello, do: :world", "end"]
             }
    end

    test "encodes links" do
      link = %Org.FormattedText.Link{
        url: "https://example.com",
        description: "Example Site"
      }

      json_map = Org.JSONEncodable.to_json_map(link)

      assert json_map == %{
               type: "link",
               url: "https://example.com",
               description: "Example Site"
             }
    end

    test "encodes complete document from parser" do
      source = """
      * TODO [#A] Main Section
      This is a paragraph with *bold* and /italic/ text.

      ** Subsection
      - Item 1
      - Item 2
        - Nested item

      #+BEGIN_SRC elixir
      IO.puts("Hello")
      #+END_SRC

      | Name | Value |
      |------+-------|
      | Foo  | 42    |
      """

      doc = Org.Parser.parse(source)
      json_map = Org.JSONEncodable.to_json_map(doc)

      # Basic structure checks
      assert json_map.type == "document"
      assert is_list(json_map.sections)
      assert length(json_map.sections) > 0

      # Check first section
      first_section = List.first(json_map.sections)
      assert first_section.type == "section"
      assert first_section.title == "Main Section"
      assert first_section.todo_keyword == "TODO"
      assert first_section.priority == "A"
    end

    test "encoder module works" do
      doc = %Org.Document{
        comments: [],
        sections: [],
        contents: [
          %Org.Paragraph{lines: ["Test paragraph"]}
        ]
      }

      encoded = Org.JSONEncoder.encode(doc)

      assert encoded == %{
               type: "document",
               comments: [],
               file_properties: %{},
               sections: [],
               contents: [
                 %{type: "paragraph", lines: ["Test paragraph"]}
               ]
             }
    end

    test "handles paragraphs with formatted text lines" do
      para = %Org.Paragraph{
        lines: [
          "Plain text",
          %Org.FormattedText{
            spans: ["Mixed ", %Org.FormattedText.Span{format: :bold, content: "bold"}, " text"]
          }
        ]
      }

      json_map = Org.JSONEncodable.to_json_map(para)

      assert json_map == %{
               type: "paragraph",
               lines: [
                 "Plain text",
                 %{
                   type: "formatted_text",
                   spans: ["Mixed ", %{type: "span", format: :bold, content: "bold"}, " text"]
                 }
               ]
             }
    end
  end
end
