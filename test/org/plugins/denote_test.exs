defmodule Org.Plugins.DenoteTest do
  use ExUnit.Case, async: true

  alias Org.Plugins.Denote
  alias Org.Plugins.Denote.{DenoteBlock, DenoteLink}

  describe "extract_denote_id/1" do
    test "extracts ID from valid Denote filename" do
      assert {:ok, "20240115T144532"} =
               Denote.extract_denote_id("20240115T144532--my-note__keyword1_keyword2.org")
    end

    test "extracts ID from filename without keywords" do
      assert {:ok, "20240115T144532"} =
               Denote.extract_denote_id("20240115T144532--my-note.org")
    end

    test "returns error for invalid filename" do
      assert :error = Denote.extract_denote_id("regular-file.org")
    end

    test "returns error for malformed ID" do
      assert :error = Denote.extract_denote_id("2024-01-15--note.org")
    end
  end

  describe "generate_filename/3" do
    test "generates filename with title only" do
      timestamp = ~U[2024-01-15 14:45:32.123456Z]
      filename = Denote.generate_filename("My Important Note", [], timestamp)
      assert filename == "20240115T144532--my-important-note.org"
    end

    test "generates filename with keywords" do
      timestamp = ~U[2024-01-15 14:45:32.123456Z]
      filename = Denote.generate_filename("My Note", ["research", "ai"], timestamp)
      assert filename == "20240115T144532--my-note__research_ai.org"
    end

    test "slugifies special characters in title" do
      timestamp = ~U[2024-01-15 14:45:32.123456Z]
      filename = Denote.generate_filename("Note: With Special! Characters?", [], timestamp)
      assert filename == "20240115T144532--note-with-special-characters.org"
    end

    test "handles empty title" do
      timestamp = ~U[2024-01-15 14:45:32.123456Z]
      filename = Denote.generate_filename("", [], timestamp)
      assert filename == "20240115T144532--.org"
    end
  end

  describe "parse/2 for Denote links" do
    test "parses denote: link with description" do
      result = Denote.parse("[[denote:20240115T144532][My Note]]", %{})
      assert {:ok, %DenoteLink{id: "20240115T144532", description: "My Note", type: :denote}} = result
    end

    test "parses denote: link without description" do
      result = Denote.parse("[[denote:20240115T144532]]", %{})
      assert {:ok, %DenoteLink{id: "20240115T144532", description: nil, type: :denote}} = result
    end

    test "parses id: link with description" do
      result = Denote.parse("[[id:20240115T144532][My Note]]", %{})
      assert {:ok, %DenoteLink{id: "20240115T144532", description: "My Note", type: :id}} = result
    end

    test "parses id: link without description" do
      result = Denote.parse("[[id:20240115T144532]]", %{})
      assert {:ok, %DenoteLink{id: "20240115T144532", description: nil, type: :id}} = result
    end

    test "handles malformed link" do
      result = Denote.parse("[[denote:incomplete", %{})
      assert {:error, :invalid_denote_link} = result
    end
  end

  describe "parse/2 for Denote dynamic blocks" do
    test "parses denote-links block" do
      content = "#+BEGIN: denote-links :filter keyword1\n"
      result = Denote.parse(content, %{})
      assert {:ok, %DenoteBlock{type: :links, params: params}} = result
      assert params[:filter] == "keyword1"
    end

    test "parses denote-backlinks block" do
      content = "#+BEGIN: denote-backlinks\n"
      result = Denote.parse(content, %{})
      assert {:ok, %DenoteBlock{type: :backlinks, params: []}} = result
    end

    test "parses denote-related block with params" do
      content = "#+BEGIN: denote-related :limit 10 :sort date\n"
      result = Denote.parse(content, %{})
      assert {:ok, %DenoteBlock{type: :related, params: params}} = result
      assert params[:limit] == "10"
      assert params[:sort] == "date"
    end
  end

  describe "parse/2 for Denote filenames" do
    test "parses full Denote filename with keywords" do
      result = Denote.parse("20240115T144532--my-research-note__ai_ml_research.org", %{})
      assert {:ok, metadata} = result
      assert metadata.id == "20240115T144532"
      assert metadata.title == "My Research Note"
      assert metadata.keywords == ["ai", "ml", "research"]
    end

    test "parses Denote filename without keywords" do
      result = Denote.parse("20240115T144532--simple-note.org", %{})
      assert {:ok, metadata} = result
      assert metadata.id == "20240115T144532"
      assert metadata.title == "Simple Note"
      assert metadata.keywords == []
    end

    test "skips non-Denote filename" do
      result = Denote.parse("regular-file.org", %{})
      assert :skip = result
    end

    test "handles filename with single word title" do
      result = Denote.parse("20240115T144532--note.org", %{})
      assert {:ok, metadata} = result
      assert metadata.title == "Note"
    end
  end

  describe "find_backlinks/2" do
    test "finds backlinks in workspace" do
      # Mock workspace structure
      workspace = %{
        file_entries: [
          %{
            filename: "20240115T144532--note1.org",
            # Would contain actual parsed document
            document: %{}
          },
          %{
            filename: "20240116T093021--note2.org",
            # Would contain link to note1
            document: %{}
          }
        ]
      }

      # This test would need actual document structures with links
      backlinks = Denote.find_backlinks(workspace, "20240115T144532")
      assert is_list(backlinks)
    end
  end

  describe "patterns/0" do
    test "returns expected patterns" do
      patterns = Denote.patterns()
      assert "[[denote:" in patterns
      assert "[[id:" in patterns
      assert "#+BEGIN: denote-" in patterns
      assert Enum.any?(patterns, fn p -> Regex.regex?(p) end)
    end
  end

  describe "priority/0" do
    test "returns higher priority for Denote patterns" do
      assert Denote.priority() == 30
    end
  end

  describe "init/1" do
    test "initializes with empty index" do
      assert {:ok, %{index: %{}}} = Denote.init([])
    end
  end

  describe "edge cases" do
    test "handles Denote ID at year boundary" do
      timestamp = ~U[2023-12-31 23:59:59.123456Z]
      filename = Denote.generate_filename("Year End Note", [], timestamp)
      assert filename == "20231231T235959--year-end-note.org"
    end

    test "handles very long title" do
      long_title = String.duplicate("very ", 50) <> "long title"
      timestamp = ~U[2024-01-15 14:45:32.123456Z]
      filename = Denote.generate_filename(long_title, [], timestamp)
      assert String.starts_with?(filename, "20240115T144532--")
      assert String.ends_with?(filename, ".org")
    end

    test "handles special characters in keywords" do
      timestamp = ~U[2024-01-15 14:45:32.123456Z]
      # Keywords should be sanitized before passing to the function
      filename = Denote.generate_filename("Note", ["key_word", "another"], timestamp)
      assert filename == "20240115T144532--note__key_word_another.org"
    end

    test "parses link with spaces in description" do
      result = Denote.parse("[[denote:20240115T144532][My Important Note Title]]", %{})
      assert {:ok, %DenoteLink{description: "My Important Note Title"}} = result
    end

    test "parses block with multiple parameters" do
      content = "#+BEGIN: denote-links :filter tag1 :sort date :limit 5\n"
      result = Denote.parse(content, %{})
      assert {:ok, %DenoteBlock{type: :links, params: params}} = result
      assert length(params) == 3
    end
  end
end
