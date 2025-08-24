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
               {:section_title, 1, "Task", "TODO", nil},
               {:section_title, 2, "Subtask", "DONE", nil},
               {:section_title, 2, "Another", nil, nil}
             ]
    end
  end

  describe "TODO priority parsing" do
    test "parses TODO with priority A" do
      source = "* TODO [#A] High priority task"
      doc = Org.Parser.parse(source)
      section = hd(doc.sections)
      assert section.title == "High priority task"
      assert section.todo_keyword == "TODO"
      assert section.priority == "A"
    end

    test "parses DONE with priority B" do
      source = "* DONE [#B] Medium priority completed task"
      doc = Org.Parser.parse(source)
      section = hd(doc.sections)
      assert section.title == "Medium priority completed task"
      assert section.todo_keyword == "DONE"
      assert section.priority == "B"
    end

    test "parses headline with priority but no TODO keyword" do
      source = "* [#C] Low priority regular headline"
      doc = Org.Parser.parse(source)
      section = hd(doc.sections)
      assert section.title == "Low priority regular headline"
      assert section.todo_keyword == nil
      assert section.priority == "C"
    end

    test "parses nested sections with mixed priorities" do
      source = """
      * TODO [#A] High Priority Project
      ** DONE [#B] Medium priority research
      ** TODO [#A] High priority implementation
      *** TODO [#C] Low priority backend
      *** [#A] High priority frontend (no TODO)
      ** Regular testing (no priority/TODO)
      """

      doc = Org.Parser.parse(source)
      project = hd(doc.sections)

      assert project.title == "High Priority Project"
      assert project.todo_keyword == "TODO"
      assert project.priority == "A"

      [research, implementation, testing] = project.children

      assert research.title == "Medium priority research"
      assert research.todo_keyword == "DONE"
      assert research.priority == "B"

      assert implementation.title == "High priority implementation"
      assert implementation.todo_keyword == "TODO"
      assert implementation.priority == "A"

      [backend, frontend] = implementation.children

      assert backend.title == "Low priority backend"
      assert backend.todo_keyword == "TODO"
      assert backend.priority == "C"

      assert frontend.title == "High priority frontend (no TODO)"
      assert frontend.todo_keyword == nil
      assert frontend.priority == "A"

      assert testing.title == "Regular testing (no priority/TODO)"
      assert testing.todo_keyword == nil
      assert testing.priority == nil
    end

    test "lexer tokenizes TODO keywords with priorities correctly" do
      tokens = Org.Lexer.lex("* TODO [#A] Task\n** DONE [#B] Subtask\n** [#C] Another")

      assert tokens == [
               {:section_title, 1, "Task", "TODO", "A"},
               {:section_title, 2, "Subtask", "DONE", "B"},
               {:section_title, 2, "Another", nil, "C"}
             ]
    end
  end
end
