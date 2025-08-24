defmodule Org.FormattedTextTest do
  use ExUnit.Case
  doctest Org.FormattedText

  alias Org.FormattedText
  alias Org.FormattedText.Span

  describe "FormattedText parsing" do
    test "parses plain text without formatting" do
      result = FormattedText.parse("This is plain text")

      assert result == %FormattedText{spans: ["This is plain text"]}
    end

    test "parses bold text" do
      result = FormattedText.parse("This is *bold* text")

      expected = %FormattedText{
        spans: [
          "This is ",
          %Span{format: :bold, content: "bold"},
          " text"
        ]
      }

      assert result == expected
    end

    test "parses italic text" do
      result = FormattedText.parse("This is /italic/ text")

      expected = %FormattedText{
        spans: [
          "This is ",
          %Span{format: :italic, content: "italic"},
          " text"
        ]
      }

      assert result == expected
    end

    test "parses underline text" do
      result = FormattedText.parse("This is _underline_ text")

      expected = %FormattedText{
        spans: [
          "This is ",
          %Span{format: :underline, content: "underline"},
          " text"
        ]
      }

      assert result == expected
    end

    test "parses code text" do
      result = FormattedText.parse("This is =code= text")

      expected = %FormattedText{
        spans: [
          "This is ",
          %Span{format: :code, content: "code"},
          " text"
        ]
      }

      assert result == expected
    end

    test "parses verbatim text" do
      result = FormattedText.parse("This is ~verbatim~ text")

      expected = %FormattedText{
        spans: [
          "This is ",
          %Span{format: :verbatim, content: "verbatim"},
          " text"
        ]
      }

      assert result == expected
    end

    test "parses strikethrough text" do
      result = FormattedText.parse("This is +strikethrough+ text")

      expected = %FormattedText{
        spans: [
          "This is ",
          %Span{format: :strikethrough, content: "strikethrough"},
          " text"
        ]
      }

      assert result == expected
    end

    test "parses multiple formatting in one line" do
      result = FormattedText.parse("*Bold* and /italic/ and =code=")

      expected = %FormattedText{
        spans: [
          %Span{format: :bold, content: "Bold"},
          " and ",
          %Span{format: :italic, content: "italic"},
          " and ",
          %Span{format: :code, content: "code"}
        ]
      }

      assert result == expected
    end

    test "handles formatting at the beginning and end" do
      result = FormattedText.parse("*Start* middle /end/")

      expected = %FormattedText{
        spans: [
          %Span{format: :bold, content: "Start"},
          " middle ",
          %Span{format: :italic, content: "end"}
        ]
      }

      assert result == expected
    end

    test "handles empty formatting gracefully" do
      result = FormattedText.parse("**")

      # Should not match empty formatting
      assert result == %FormattedText{spans: ["**"]}
    end
  end

  describe "FormattedText conversion" do
    test "converts to org string" do
      formatted = %FormattedText{
        spans: [
          "This is ",
          %Span{format: :bold, content: "bold"},
          " and ",
          %Span{format: :italic, content: "italic"}
        ]
      }

      result = FormattedText.to_org_string(formatted)
      assert result == "This is *bold* and /italic/"
    end

    test "converts to plain text" do
      formatted = %FormattedText{
        spans: [
          "This is ",
          %Span{format: :bold, content: "bold"},
          " and ",
          %Span{format: :italic, content: "italic"}
        ]
      }

      result = FormattedText.to_plain_text(formatted)
      assert result == "This is bold and italic"
    end

    test "checks if empty" do
      empty_formatted = %FormattedText{spans: []}
      assert FormattedText.empty?(empty_formatted) == true

      whitespace_formatted = %FormattedText{
        spans: [
          "   ",
          %Span{format: :bold, content: "  "},
          "\t"
        ]
      }

      assert FormattedText.empty?(whitespace_formatted) == true

      non_empty_formatted = %FormattedText{
        spans: ["Hello"]
      }

      assert FormattedText.empty?(non_empty_formatted) == false
    end
  end

  describe "FormattedText content protocol" do
    test "content type identification" do
      formatted = %FormattedText{spans: ["Hello"]}
      assert Org.Content.content_type(formatted) == :formatted_text
    end

    test "reverse recursive" do
      formatted = %FormattedText{
        spans: [
          "First",
          %Span{format: :bold, content: "Second"},
          "Third"
        ]
      }

      reversed = Org.Content.reverse_recursive(formatted)

      expected = %FormattedText{
        spans: [
          "Third",
          %Span{format: :bold, content: "Second"},
          "First"
        ]
      }

      assert reversed == expected
    end

    test "can merge with other formatted text" do
      f1 = %FormattedText{spans: ["Hello"]}
      f2 = %FormattedText{spans: ["World"]}

      assert Org.Content.can_merge?(f1, f2) == true
      assert Org.Content.can_merge?(f1, %Org.Paragraph{lines: []}) == false
    end

    test "merge formatted text" do
      f1 = %FormattedText{spans: ["Hello "]}
      f2 = %FormattedText{spans: ["World"]}

      merged = Org.Content.merge(f1, f2)
      expected = %FormattedText{spans: ["Hello ", "World"]}

      assert merged == expected
    end

    test "validates formatted text" do
      valid_formatted = %FormattedText{
        spans: [
          "Hello ",
          %Span{format: :bold, content: "World"}
        ]
      }

      assert Org.Content.validate(valid_formatted) == {:ok, valid_formatted}

      invalid_formatted = %FormattedText{spans: [123, :invalid]}
      assert {:error, _reason} = Org.Content.validate(invalid_formatted)
    end

    test "metadata extraction" do
      formatted = %FormattedText{
        spans: [
          "Hello ",
          %Span{format: :bold, content: "beautiful"},
          " ",
          %Span{format: :italic, content: "world"}
        ]
      }

      metadata = Org.Content.metadata(formatted)

      assert metadata.span_count == 4
      assert metadata.character_count == String.length("Hello beautiful world")
      assert metadata.word_count == 3
      assert metadata.formats == %{bold: 1, italic: 1}
    end
  end

  describe "Paragraph integration" do
    test "paragraph with formatting detection" do
      line_with_formatting = "This has *bold* text"
      line_without_formatting = "This is plain"

      result_with = Org.Paragraph.parse_line_formatting(line_with_formatting)
      result_without = Org.Paragraph.parse_line_formatting(line_without_formatting)

      assert match?(%FormattedText{}, result_with)
      assert result_without == "This is plain"
    end

    test "creating formatted paragraph" do
      lines = [
        "Plain text",
        "Text with *bold* formatting",
        "More /italic/ text"
      ]

      paragraph = Org.Paragraph.new_formatted(lines)

      assert length(paragraph.lines) == 3
      assert is_binary(Enum.at(paragraph.lines, 0))
      assert match?(%FormattedText{}, Enum.at(paragraph.lines, 1))
      assert match?(%FormattedText{}, Enum.at(paragraph.lines, 2))
    end

    test "paragraph to_text with mixed content" do
      paragraph = %Org.Paragraph{
        lines: [
          "Plain line",
          %FormattedText{
            spans: [
              "Formatted ",
              %Span{format: :bold, content: "line"}
            ]
          }
        ]
      }

      result = Org.Content.to_text(paragraph)
      assert result == "Plain line\nFormatted line"
    end
  end
end
