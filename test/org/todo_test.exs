defmodule Org.TodoTest do
  use ExUnit.Case

  describe "TODO keyword parsing" do
    test "parses TODO keyword" do
      source = "* TODO Task to complete"
      doc = Org.Parser.parse(source)
      section = hd(doc.sections)
      assert section.title == "Task to complete"
      assert section.todo_keyword == "TODO"
    end

    test "parses DONE keyword" do
      source = "* DONE Completed task"
      doc = Org.Parser.parse(source)
      section = hd(doc.sections)
      assert section.title == "Completed task"
      assert section.todo_keyword == "DONE"
    end

    test "parses headline without TODO keyword" do
      source = "* Regular headline"
      doc = Org.Parser.parse(source)
      section = hd(doc.sections)
      assert section.title == "Regular headline"
      assert section.todo_keyword == nil
    end

    test "parses nested sections with mixed TODO states" do
      source = """
      * TODO Project
      ** DONE Research
      ** TODO Implementation
      *** TODO Backend
      *** Frontend
      ** Testing
      """
      doc = Org.Parser.parse(source)
      project = hd(doc.sections)
      
      assert project.title == "Project"
      assert project.todo_keyword == "TODO"
      
      [research, implementation, testing] = project.children
      
      assert research.title == "Research"
      assert research.todo_keyword == "DONE"
      
      assert implementation.title == "Implementation"
      assert implementation.todo_keyword == "TODO"
      
      [backend, frontend] = implementation.children
      
      assert backend.title == "Backend"
      assert backend.todo_keyword == "TODO"
      
      assert frontend.title == "Frontend"
      assert frontend.todo_keyword == nil
      
      assert testing.title == "Testing"
      assert testing.todo_keyword == nil
    end

    test "lexer tokenizes TODO keywords correctly" do
      tokens = Org.Lexer.lex("* TODO Task\n** DONE Subtask\n** Another")
      assert tokens == [
        {:section_title, 1, "Task", "TODO"},
        {:section_title, 2, "Subtask", "DONE"},
        {:section_title, 2, "Another", nil}
      ]
    end
  end
end