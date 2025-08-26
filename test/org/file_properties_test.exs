defmodule Org.FilePropertiesTest do
  use ExUnit.Case
  doctest Org.FileProperties

  alias Org.FileProperties

  describe "parse_file_property_line/1" do
    test "parses valid file property lines" do
      assert FileProperties.parse_file_property_line("#+TITLE: My Document") == {"TITLE", "My Document"}
      assert FileProperties.parse_file_property_line("#+AUTHOR: John Doe") == {"AUTHOR", "John Doe"}
      assert FileProperties.parse_file_property_line("#+EMAIL: john@example.com") == {"EMAIL", "john@example.com"}
      assert FileProperties.parse_file_property_line("#+DATE: 2024-01-15") == {"DATE", "2024-01-15"}

      assert FileProperties.parse_file_property_line("#+FILETAGS: :project:important:") ==
               {"FILETAGS", ":project:important:"}
    end

    test "handles properties with extra whitespace" do
      assert FileProperties.parse_file_property_line("#+TITLE:   My Document   ") == {"TITLE", "My Document"}
      assert FileProperties.parse_file_property_line("  #+AUTHOR: John Doe  ") == {"AUTHOR", "John Doe"}
      # Invalid format
      assert FileProperties.parse_file_property_line("#+   EMAIL   :   john@example.com   ") == nil
    end

    test "handles properties with colons in values" do
      assert FileProperties.parse_file_property_line("#+URL: https://example.com:8080/path") ==
               {"URL", "https://example.com:8080/path"}
    end

    test "handles properties with underscores and numbers" do
      assert FileProperties.parse_file_property_line("#+EXPORT_FILE_NAME: output.html") ==
               {"EXPORT_FILE_NAME", "output.html"}

      assert FileProperties.parse_file_property_line("#+HTML_HEAD_EXTRA: <style>body{color:red}</style>") ==
               {"HTML_HEAD_EXTRA", "<style>body{color:red}</style>"}
    end

    test "rejects invalid lines" do
      assert FileProperties.parse_file_property_line("# Not a property") == nil
      assert FileProperties.parse_file_property_line("#+INVALID") == nil
      assert FileProperties.parse_file_property_line("#+") == nil
      assert FileProperties.parse_file_property_line("Regular text") == nil
      assert FileProperties.parse_file_property_line("#+title: lowercase not allowed") == nil
      assert FileProperties.parse_file_property_line("#+123INVALID: starts with number") == nil
    end

    test "handles empty values" do
      assert FileProperties.parse_file_property_line("#+TITLE:") == {"TITLE", ""}
      assert FileProperties.parse_file_property_line("#+AUTHOR:   ") == {"AUTHOR", ""}
    end
  end

  describe "parse_properties/1" do
    test "parses file properties from the beginning of lines" do
      lines = [
        "#+TITLE: My Document",
        "#+AUTHOR: John Doe",
        "#+EMAIL: john@example.com",
        "",
        "* First Section",
        "Content here"
      ]

      {properties, remaining} = FileProperties.parse_properties(lines)

      assert properties == %{
               "TITLE" => "My Document",
               "AUTHOR" => "John Doe",
               "EMAIL" => "john@example.com"
             }

      assert remaining == ["", "* First Section", "Content here"]
    end

    test "handles empty lines between properties" do
      lines = [
        "#+TITLE: My Document",
        "",
        "#+AUTHOR: John Doe",
        "",
        "",
        "#+DATE: 2024-01-15",
        "",
        "* Section"
      ]

      {properties, remaining} = FileProperties.parse_properties(lines)

      assert properties == %{
               "TITLE" => "My Document",
               "AUTHOR" => "John Doe",
               "DATE" => "2024-01-15"
             }

      assert remaining == ["", "* Section"]
    end

    test "stops parsing at first non-property line" do
      lines = [
        "#+TITLE: My Document",
        "#+AUTHOR: John Doe",
        "Regular content line",
        "#+DATE: 2024-01-15",
        "* Section"
      ]

      {properties, remaining} = FileProperties.parse_properties(lines)

      assert properties == %{
               "TITLE" => "My Document",
               "AUTHOR" => "John Doe"
             }

      assert remaining == ["Regular content line", "#+DATE: 2024-01-15", "* Section"]
    end

    test "handles empty list" do
      {properties, remaining} = FileProperties.parse_properties([])
      assert properties == %{}
      assert remaining == []
    end

    test "handles list with no properties" do
      lines = ["* Section", "Content"]
      {properties, remaining} = FileProperties.parse_properties(lines)
      assert properties == %{}
      assert remaining == lines
    end

    test "handles only empty lines" do
      lines = ["", "", ""]
      {properties, remaining} = FileProperties.parse_properties(lines)
      assert properties == %{}
      assert remaining == []
    end
  end

  describe "render_properties/1" do
    test "renders properties to org format" do
      properties = %{
        "TITLE" => "My Document",
        "AUTHOR" => "John Doe",
        "EMAIL" => "john@example.com"
      }

      lines = FileProperties.render_properties(properties)

      assert "#+AUTHOR: John Doe" in lines
      assert "#+EMAIL: john@example.com" in lines
      assert "#+TITLE: My Document" in lines
    end

    test "sorts properties alphabetically" do
      properties = %{
        "ZEBRA" => "value",
        "ALPHA" => "value",
        "MIDDLE" => "value"
      }

      lines = FileProperties.render_properties(properties)

      assert lines == [
               "#+ALPHA: value",
               "#+MIDDLE: value",
               "#+ZEBRA: value"
             ]
    end

    test "renders empty properties as empty list" do
      assert FileProperties.render_properties(%{}) == []
    end

    test "handles properties with special characters in values" do
      properties = %{
        "HTML_HEAD" => "<style>body { color: red; }</style>",
        "URL" => "https://example.com:8080/path?param=value"
      }

      lines = FileProperties.render_properties(properties)

      assert "#+HTML_HEAD: <style>body { color: red; }</style>" in lines
      assert "#+URL: https://example.com:8080/path?param=value" in lines
    end
  end

  describe "file_property_line?/1" do
    test "identifies file property lines" do
      assert FileProperties.file_property_line?("#+TITLE: My Document") == true
      assert FileProperties.file_property_line?("  #+AUTHOR: John Doe  ") == true
      assert FileProperties.file_property_line?("#+EMAIL: test@example.com") == true
      assert FileProperties.file_property_line?("#+EXPORT_FILE_NAME: output.html") == true
    end

    test "rejects non-property lines" do
      assert FileProperties.file_property_line?("# Comment") == false
      assert FileProperties.file_property_line?("Regular text") == false
      assert FileProperties.file_property_line?("* Section") == false
      assert FileProperties.file_property_line?("#+BEGIN_SRC") == false
      assert FileProperties.file_property_line?("#+title: lowercase") == false
    end

    test "handles edge cases" do
      assert FileProperties.file_property_line?("#+") == false
      assert FileProperties.file_property_line?("") == false
      assert FileProperties.file_property_line?("   ") == false
    end
  end

  describe "extract_structured_properties/1" do
    test "extracts common properties into structured format" do
      properties = %{
        "TITLE" => "My Document",
        "AUTHOR" => "John Doe",
        "EMAIL" => "john@example.com",
        "DATE" => "2024-01-15",
        "FILETAGS" => ":project:important:urgent:",
        "DESCRIPTION" => "A test document",
        "KEYWORDS" => "test, document, example",
        "LANGUAGE" => "en",
        "OPTIONS" => "toc:nil",
        "STARTUP" => "fold"
      }

      structured = FileProperties.extract_structured_properties(properties)

      assert structured.title == "My Document"
      assert structured.author == "John Doe"
      assert structured.email == "john@example.com"
      assert structured.date == "2024-01-15"
      assert structured.tags == ["project", "important", "urgent"]
      assert structured.description == "A test document"
      assert structured.keywords == "test, document, example"
      assert structured.language == "en"
      assert structured.options == "toc:nil"
      assert structured.startup == "fold"
    end

    test "handles missing properties" do
      properties = %{"TITLE" => "My Document"}

      structured = FileProperties.extract_structured_properties(properties)

      assert structured.title == "My Document"
      assert structured.author == nil
      assert structured.email == nil
      assert structured.date == nil
      assert structured.tags == []
      assert structured.description == nil
      assert structured.keywords == nil
      assert structured.language == nil
      assert structured.options == nil
      assert structured.startup == nil
    end

    test "parses FILETAGS correctly" do
      # Test various FILETAGS formats
      test_cases = [
        {%{"FILETAGS" => ":tag1:tag2:"}, ["tag1", "tag2"]},
        {%{"FILETAGS" => ":single:"}, ["single"]},
        {%{"FILETAGS" => ":"}, []},
        {%{"FILETAGS" => ""}, []},
        {%{"FILETAGS" => "   :tag1:tag2:   "}, ["tag1", "tag2"]},
        {%{}, []}
      ]

      for {props, expected_tags} <- test_cases do
        structured = FileProperties.extract_structured_properties(props)

        assert structured.tags == expected_tags,
               "Expected tags #{inspect(expected_tags)} for #{inspect(props)}, got #{inspect(structured.tags)}"
      end
    end
  end
end
