defmodule Org.TodoWorkflowTest do
  use ExUnit.Case
  doctest Org.Writer

  describe "workflow configuration" do
    test "can create basic todo sequence" do
      sequence = Org.create_todo_sequence(["TODO"], ["DONE"])

      assert sequence.active == ["TODO"]
      assert sequence.done == ["DONE"]
    end

    test "can create complex todo sequence" do
      sequence = Org.create_todo_sequence(["TODO", "DOING", "REVIEW"], ["DONE", "CANCELLED"])

      assert sequence.active == ["TODO", "DOING", "REVIEW"]
      assert sequence.done == ["DONE", "CANCELLED"]
    end

    test "can create workflow config with multiple sequences" do
      basic = Org.create_todo_sequence(["TODO"], ["DONE"])
      dev = Org.create_todo_sequence(["TODO", "INPROGRESS", "REVIEW"], ["DONE", "CANCELLED"])
      config = Org.create_workflow_config([basic, dev])

      assert length(config.sequences) == 2
      assert config.default_sequence == basic
    end

    test "default workflow config is TODO -> DONE" do
      config = Org.default_workflow_config()

      assert config.default_sequence.active == ["TODO"]
      assert config.default_sequence.done == ["DONE"]
      assert length(config.sequences) == 1
    end

    test "can get all keywords from config" do
      basic = Org.create_todo_sequence(["TODO"], ["DONE"])
      dev = Org.create_todo_sequence(["BUG", "FIXING"], ["FIXED", "WONTFIX"])
      config = Org.create_workflow_config([basic, dev])

      keywords = Org.all_todo_keywords(config)

      assert "TODO" in keywords
      assert "DONE" in keywords
      assert "BUG" in keywords
      assert "FIXING" in keywords
      assert "FIXED" in keywords
      assert "WONTFIX" in keywords
      assert length(keywords) == 6
    end
  end

  describe "todo cycling" do
    test "cycles from nil to first active state" do
      doc = Org.load_string("* Task")
      doc = Org.cycle_todo(doc, ["Task"])
      task = Org.section(doc, ["Task"])

      assert task.todo_keyword == "TODO"
    end

    test "cycles from TODO to DONE with default config" do
      doc = Org.load_string("* TODO Task")
      doc = Org.cycle_todo(doc, ["Task"])
      task = Org.section(doc, ["Task"])

      assert task.todo_keyword == "DONE"
    end

    test "cycles from DONE to nil with default config" do
      doc = Org.load_string("* DONE Task")
      doc = Org.cycle_todo(doc, ["Task"])
      task = Org.section(doc, ["Task"])

      assert task.todo_keyword == nil
    end

    test "cycles through complex workflow sequence" do
      dev_sequence = Org.create_todo_sequence(["TODO", "DOING", "REVIEW"], ["DONE", "CANCELLED"])
      config = Org.create_workflow_config([dev_sequence])

      # Start with nil -> TODO
      doc = Org.load_string("* Task")
      doc = Org.cycle_todo(doc, ["Task"], config)
      task = Org.section(doc, ["Task"])
      assert task.todo_keyword == "TODO"

      # Transition: TODO -> DOING
      doc = Org.cycle_todo(doc, ["Task"], config)
      task = Org.section(doc, ["Task"])
      assert task.todo_keyword == "DOING"

      # DOING -> REVIEW
      doc = Org.cycle_todo(doc, ["Task"], config)
      task = Org.section(doc, ["Task"])
      assert task.todo_keyword == "REVIEW"

      # REVIEW -> DONE
      doc = Org.cycle_todo(doc, ["Task"], config)
      task = Org.section(doc, ["Task"])
      assert task.todo_keyword == "DONE"

      # DONE -> CANCELLED
      doc = Org.cycle_todo(doc, ["Task"], config)
      task = Org.section(doc, ["Task"])
      assert task.todo_keyword == "CANCELLED"

      # CANCELLED -> nil
      doc = Org.cycle_todo(doc, ["Task"], config)
      task = Org.section(doc, ["Task"])
      assert task.todo_keyword == nil
    end

    test "cycles backward from DONE to TODO" do
      doc = Org.load_string("* DONE Task")
      doc = Org.cycle_todo_backward(doc, ["Task"])
      task = Org.section(doc, ["Task"])

      assert task.todo_keyword == "TODO"
    end

    test "cycles backward from TODO to nil" do
      doc = Org.load_string("* TODO Task")
      doc = Org.cycle_todo_backward(doc, ["Task"])
      task = Org.section(doc, ["Task"])

      assert task.todo_keyword == nil
    end

    test "cycles backward from nil to DONE" do
      doc = Org.load_string("* Task")
      doc = Org.cycle_todo_backward(doc, ["Task"])
      task = Org.section(doc, ["Task"])

      assert task.todo_keyword == "DONE"
    end

    test "cycles backward through complex workflow sequence" do
      dev_sequence = Org.create_todo_sequence(["TODO", "DOING", "REVIEW"], ["DONE", "CANCELLED"])
      config = Org.create_workflow_config([dev_sequence])

      # Start by setting REVIEW manually since lexer doesn't recognize it
      doc = Org.load_string("* Task")
      doc = Org.set_todo_keyword(doc, ["Task"], "REVIEW")
      doc = Org.cycle_todo_backward(doc, ["Task"], config)
      task = Org.section(doc, ["Task"])
      assert task.todo_keyword == "DOING"

      # DOING -> TODO
      doc = Org.cycle_todo_backward(doc, ["Task"], config)
      task = Org.section(doc, ["Task"])
      assert task.todo_keyword == "TODO"

      # Transition: TODO -> nil
      doc = Org.cycle_todo_backward(doc, ["Task"], config)
      task = Org.section(doc, ["Task"])
      assert task.todo_keyword == nil
    end

    test "handles unknown keywords by defaulting to first active state" do
      doc = Org.load_string("* UNKNOWN Task")
      doc = Org.cycle_todo(doc, ["UNKNOWN Task"])
      task = Org.section(doc, ["UNKNOWN Task"])

      assert task.todo_keyword == "TODO"
    end
  end

  describe "todo keyword management" do
    test "can set specific todo keyword" do
      doc = Org.load_string("* Task")
      doc = Org.set_todo_keyword(doc, ["Task"], "DOING")
      task = Org.section(doc, ["Task"])

      assert task.todo_keyword == "DOING"
    end

    test "can clear todo keyword" do
      doc = Org.load_string("* TODO Task")
      doc = Org.clear_todo_keyword(doc, ["Task"])
      task = Org.section(doc, ["Task"])

      assert task.todo_keyword == nil
    end

    test "can replace existing todo keyword" do
      doc = Org.load_string("* TODO Task")
      doc = Org.set_todo_keyword(doc, ["Task"], "DOING")
      task = Org.section(doc, ["Task"])

      assert task.todo_keyword == "DOING"
    end
  end

  describe "todo keyword queries" do
    test "identifies done keywords correctly" do
      config = Org.default_workflow_config()

      assert Org.todo_keyword_done?("DONE", config) == true
      assert Org.todo_keyword_done?("TODO", config) == false
      assert Org.todo_keyword_done?(nil, config) == false
    end

    test "identifies active keywords correctly" do
      config = Org.default_workflow_config()

      assert Org.todo_keyword_active?("TODO", config) == true
      assert Org.todo_keyword_active?("DONE", config) == false
      assert Org.todo_keyword_active?(nil, config) == false
    end

    test "identifies keywords in complex workflow" do
      dev_sequence = Org.create_todo_sequence(["TODO", "DOING", "REVIEW"], ["DONE", "CANCELLED"])
      config = Org.create_workflow_config([dev_sequence])

      # Active states
      assert Org.todo_keyword_active?("TODO", config) == true
      assert Org.todo_keyword_active?("DOING", config) == true
      assert Org.todo_keyword_active?("REVIEW", config) == true

      # Done states
      assert Org.todo_keyword_done?("DONE", config) == true
      assert Org.todo_keyword_done?("CANCELLED", config) == true

      # Not in this workflow
      assert Org.todo_keyword_active?("UNKNOWN", config) == false
      assert Org.todo_keyword_done?("UNKNOWN", config) == false
    end
  end

  describe "todo section extraction" do
    test "extracts sections by specific todo keyword" do
      doc =
        Org.load_string("""
        * TODO Task 1
        * DONE Task 2  
        * TODO Task 3
        * Regular Section
        """)

      todo_sections = Org.sections_by_todo_keyword(doc, "TODO")
      done_sections = Org.sections_by_todo_keyword(doc, "DONE")

      assert length(todo_sections) == 2
      assert length(done_sections) == 1

      todo_titles = Enum.map(todo_sections, & &1.title)
      assert "Task 1" in todo_titles
      assert "Task 3" in todo_titles

      done_titles = Enum.map(done_sections, & &1.title)
      assert "Task 2" in done_titles
    end

    test "extracts all todo sections" do
      doc =
        Org.load_string("""
        * TODO Task 1
        * Regular Section
        * DONE Task 2
        * Another Regular Section  
        * TODO Task 3
        """)

      all_todos = Org.all_todo_sections(doc)

      assert length(all_todos) == 3
      titles = Enum.map(all_todos, & &1.title)
      assert "Task 1" in titles
      assert "Task 2" in titles
      assert "Task 3" in titles
      refute "Regular Section" in titles
      refute "Another Regular Section" in titles
    end

    test "extracts active todo sections" do
      config = Org.default_workflow_config()

      doc =
        Org.load_string("""
        * TODO Task 1
        * DONE Task 2
        * TODO Task 3
        * Regular Section
        """)

      active_todos = Org.active_todo_sections(doc, config)

      assert length(active_todos) == 2
      titles = Enum.map(active_todos, & &1.title)
      assert "Task 1" in titles
      assert "Task 3" in titles
      refute "Task 2" in titles
    end

    test "extracts done todo sections" do
      config = Org.default_workflow_config()

      doc =
        Org.load_string("""
        * TODO Task 1
        * DONE Task 2
        * DONE Task 3
        * Regular Section
        """)

      done_todos = Org.done_todo_sections(doc, config)

      assert length(done_todos) == 2
      titles = Enum.map(done_todos, & &1.title)
      assert "Task 2" in titles
      assert "Task 3" in titles
      refute "Task 1" in titles
    end

    test "extracts nested todo sections" do
      doc =
        Org.load_string("""
        * Project
        ** TODO Subtask 1
        *** DONE Sub-subtask
        ** Regular Subtask
        ** TODO Subtask 2
        * TODO Another Project
        """)

      all_todos = Org.all_todo_sections(doc)

      assert length(all_todos) == 4
      titles = Enum.map(all_todos, & &1.title)
      assert "Subtask 1" in titles
      assert "Sub-subtask" in titles
      assert "Subtask 2" in titles
      assert "Another Project" in titles
      refute "Project" in titles
      refute "Regular Subtask" in titles
    end
  end

  describe "workflow with multiple sequences" do
    test "handles multiple workflow sequences correctly" do
      regular = Org.create_todo_sequence(["TODO"], ["DONE"])
      bug = Org.create_todo_sequence(["BUG", "INVESTIGATING"], ["FIXED", "WONTFIX"])
      config = Org.create_workflow_config([regular, bug], regular)

      # Test regular workflow (TODO is recognized by lexer)
      doc = Org.load_string("* TODO Regular Task")
      doc = Org.cycle_todo(doc, ["Regular Task"], config)
      task = Org.section(doc, ["Regular Task"])
      assert task.todo_keyword == "DONE"

      # Test setting BUG manually since it's not recognized by lexer
      doc = Org.load_string("* Critical Issue")
      doc = Org.set_todo_keyword(doc, ["Critical Issue"], "BUG")
      doc = Org.cycle_todo(doc, ["Critical Issue"], config)
      task = Org.section(doc, ["Critical Issue"])
      assert task.todo_keyword == "INVESTIGATING"

      doc = Org.cycle_todo(doc, ["Critical Issue"], config)
      task = Org.section(doc, ["Critical Issue"])
      assert task.todo_keyword == "FIXED"

      doc = Org.cycle_todo(doc, ["Critical Issue"], config)
      task = Org.section(doc, ["Critical Issue"])
      assert task.todo_keyword == "WONTFIX"
    end

    test "extracts sections by workflow type" do
      regular = Org.create_todo_sequence(["TODO"], ["DONE"])
      config = Org.create_workflow_config([regular])

      doc =
        Org.load_string("""
        * TODO Regular Task 1
        * TODO Another Task  
        * DONE Completed Task
        * Regular Section
        """)

      active_sections = Org.active_todo_sections(doc, config)
      done_sections = Org.done_todo_sections(doc, config)

      # Active: TODO
      assert length(active_sections) == 2
      active_titles = Enum.map(active_sections, & &1.title)
      assert "Regular Task 1" in active_titles
      assert "Another Task" in active_titles

      # Done: DONE
      assert length(done_sections) == 1
      done_titles = Enum.map(done_sections, & &1.title)
      assert "Completed Task" in done_titles
    end
  end

  describe "serialization with todo workflows" do
    test "serializes todo keywords correctly after cycling" do
      doc = Org.load_string("* Task")

      # Cycle to TODO
      doc = Org.cycle_todo(doc, ["Task"])
      serialized = Org.to_org_string(doc)
      assert serialized =~ "* TODO Task"

      # Parse and cycle to DONE
      doc = Org.load_string(serialized)
      doc = Org.cycle_todo(doc, ["Task"])
      serialized = Org.to_org_string(doc)
      assert serialized =~ "* DONE Task"

      # Parse and cycle to nil
      doc = Org.load_string(serialized)
      doc = Org.cycle_todo(doc, ["Task"])
      serialized = Org.to_org_string(doc)
      assert serialized =~ "* Task"
      refute serialized =~ "TODO"
      refute serialized =~ "DONE"
    end

    test "preserves other section properties during todo cycling" do
      doc = Org.load_string("* TODO [#A] Important Task")
      doc = Org.cycle_todo(doc, ["Important Task"])

      task = Org.section(doc, ["Important Task"])
      assert task.todo_keyword == "DONE"
      assert task.priority == "A"
      assert task.title == "Important Task"

      serialized = Org.to_org_string(doc)
      assert serialized =~ "* DONE [#A] Important Task"
    end
  end

  describe "edge cases" do
    test "handles empty sequences gracefully" do
      empty_sequence = Org.create_todo_sequence([], ["DONE"])
      config = Org.create_workflow_config([empty_sequence])

      doc = Org.load_string("* Task")
      doc = Org.cycle_todo(doc, ["Task"], config)
      task = Org.section(doc, ["Task"])

      # Should fall back to DONE since no active states
      assert task.todo_keyword == "DONE"
    end

    test "handles workflow cycling on non-existent sections" do
      doc = Org.load_string("* Task")

      # Trying to cycle non-existent section should not crash
      result_doc = Org.cycle_todo(doc, ["Non Existent"], nil)

      # Should return unchanged document
      assert result_doc == doc
    end

    test "handles cycling with nil workflow config" do
      doc = Org.load_string("* Task")
      doc = Org.cycle_todo(doc, ["Task"], nil)
      task = Org.section(doc, ["Task"])

      # Should use default workflow
      assert task.todo_keyword == "TODO"
    end
  end
end
