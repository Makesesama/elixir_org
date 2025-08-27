defmodule Org.TagInheritanceTest do
  use ExUnit.Case
  doctest Org

  describe "tag parsing in lexer" do
    test "parses section with single tag" do
      tokens = Org.Lexer.lex("* Meeting :work:")

      assert tokens == [
               {:section_title, 1, "Meeting", nil, nil, ["work"]}
             ]
    end

    test "parses section with multiple tags" do
      tokens = Org.Lexer.lex("* TODO Project planning :work:urgent:project:")

      assert tokens == [
               {:section_title, 1, "Project planning", "TODO", nil, ["work", "urgent", "project"]}
             ]
    end

    test "parses section with priority and tags" do
      tokens = Org.Lexer.lex("** DONE [#A] Important task :work:deadline:")

      assert tokens == [
               {:section_title, 2, "Important task", "DONE", "A", ["work", "deadline"]}
             ]
    end

    test "parses section without tags" do
      tokens = Org.Lexer.lex("* Regular section")

      assert tokens == [
               {:section_title, 1, "Regular section", nil, nil, []}
             ]
    end

    test "handles edge case with colon in title but no tags" do
      tokens = Org.Lexer.lex("* Meeting at 10:30 AM")

      assert tokens == [
               {:section_title, 1, "Meeting at 10:30 AM", nil, nil, []}
             ]
    end
  end

  describe "tag inheritance" do
    test "serialization shows inherited vs direct tags" do
      content = """
      #+FILETAGS: global

      * Parent :work:
      ** Child :urgent:
      """

      doc = Org.Parser.parse(content, mode: :flexible)
      serialized = Org.to_org_string(doc)

      # Parent should show (global) for inherited file tag, work for direct
      assert String.contains?(serialized, "* Parent :(global):work:")

      # Child should show (global) (work) for inherited tags, urgent for direct
      assert String.contains?(serialized, "** Child :(global):(work):urgent:")
    end

    test "section helper functions return correct tag types" do
      content = """
      #+FILETAGS: global

      * Parent :work:
      ** Child :urgent:
      """

      doc = Org.Parser.parse(content, mode: :flexible)
      parent = Org.section(doc, ["Parent"])
      child = Org.section(doc, ["Parent", "Child"])

      # Parent tags
      assert Org.Section.inherited_tags(parent) == ["global"]
      assert Org.Section.direct_tags(parent) == ["work"]
      assert Org.Section.effective_tags(parent) == ["global", "work"]

      # Child tags
      assert Org.Section.inherited_tags(child) == ["global", "work"]
      assert Org.Section.direct_tags(child) == ["urgent"]
      assert Org.Section.effective_tags(child) == ["global", "work", "urgent"]
    end

    test "top-level sections inherit file tags" do
      doc =
        Org.load_string("""
        #+FILETAGS: project meta
        * Section 1 :work:
        * Section 2 :personal:
        """)

      section1 = Org.section(doc, ["Section 1"])
      section2 = Org.section(doc, ["Section 2"])

      assert "project" in section1.tags
      assert "meta" in section1.tags
      assert "work" in section1.tags
      assert length(section1.tags) == 3

      assert "project" in section2.tags
      assert "meta" in section2.tags
      assert "personal" in section2.tags
      assert length(section2.tags) == 3
    end

    test "nested sections inherit parent tags" do
      doc =
        Org.load_string("""
        * Project :work:
        ** Task 1 :urgent:
        ** Task 2 :review:
        *** Subtask :detail:
        """)

      project = Org.section(doc, ["Project"])
      task1 = Org.section(doc, ["Project", "Task 1"])
      task2 = Org.section(doc, ["Project", "Task 2"])
      subtask = Org.section(doc, ["Project", "Task 2", "Subtask"])

      # Top level has only its own tags
      assert project.tags == ["work"]

      # Second level inherits from parent
      assert "work" in task1.tags
      assert "urgent" in task1.tags
      assert length(task1.tags) == 2

      assert "work" in task2.tags
      assert "review" in task2.tags
      assert length(task2.tags) == 2

      # Third level inherits from all ancestors
      assert "work" in subtask.tags
      assert "review" in subtask.tags
      assert "detail" in subtask.tags
      assert length(subtask.tags) == 3
    end

    test "file tags and nested inheritance work together" do
      doc =
        Org.load_string("""
        #+FILETAGS: :company:tracking:
        * Department :engineering:
        ** Team :backend:
        *** Project :api:
        """)

      department = Org.section(doc, ["Department"])
      team = Org.section(doc, ["Department", "Team"])
      project = Org.section(doc, ["Department", "Team", "Project"])

      # Department inherits file tags + its own
      expected_dept_tags = ["company", "tracking", "engineering"]
      assert Enum.sort(department.tags) == Enum.sort(expected_dept_tags)

      # Team inherits all parent tags + its own
      expected_team_tags = ["company", "tracking", "engineering", "backend"]
      assert Enum.sort(team.tags) == Enum.sort(expected_team_tags)

      # Project inherits all ancestor tags + its own
      expected_project_tags = ["company", "tracking", "engineering", "backend", "api"]
      assert Enum.sort(project.tags) == Enum.sort(expected_project_tags)
    end

    test "handles empty filetags gracefully" do
      doc =
        Org.load_string("""
        #+FILETAGS:
        * Section :work:
        """)

      section = Org.section(doc, ["Section"])
      assert section.tags == ["work"]
    end

    test "handles no filetags gracefully" do
      doc =
        Org.load_string("""
        * Section :work:
        ** Subsection :urgent:
        """)

      section = Org.section(doc, ["Section"])
      subsection = Org.section(doc, ["Section", "Subsection"])

      assert section.tags == ["work"]
      assert Enum.sort(subsection.tags) == Enum.sort(["work", "urgent"])
    end

    test "preserves tag order (file tags first, then inherited, then own)" do
      doc =
        Org.load_string("""
        #+FILETAGS: file1 file2
        * Parent :parent1:parent2:
        ** Child :child1:child2:
        """)

      child = Org.section(doc, ["Parent", "Child"])

      # Should be: file tags, parent tags, child tags
      expected_tags = ["file1", "file2", "parent1", "parent2", "child1", "child2"]
      assert child.tags == expected_tags
    end

    test "handles sections without tags" do
      doc =
        Org.load_string("""
        #+FILETAGS: global
        * Parent :work:
        ** Child with no tags
        *** Grandchild :specific:
        """)

      parent = Org.section(doc, ["Parent"])
      child = Org.section(doc, ["Parent", "Child with no tags"])
      grandchild = Org.section(doc, ["Parent", "Child with no tags", "Grandchild"])

      assert Enum.sort(parent.tags) == Enum.sort(["global", "work"])
      assert Enum.sort(child.tags) == Enum.sort(["global", "work"])
      assert Enum.sort(grandchild.tags) == Enum.sort(["global", "work", "specific"])
    end
  end

  describe "filetags parsing formats" do
    test "parses colon-separated filetags" do
      doc =
        Org.load_string("""
        #+FILETAGS: :project:work:meta:
        * Section
        """)

      section = Org.section(doc, ["Section"])
      assert Enum.sort(section.tags) == Enum.sort(["project", "work", "meta"])
    end

    test "parses space-separated filetags" do
      doc =
        Org.load_string("""
        #+FILETAGS: project work meta
        * Section
        """)

      section = Org.section(doc, ["Section"])
      assert Enum.sort(section.tags) == Enum.sort(["project", "work", "meta"])
    end

    test "handles mixed whitespace in filetags" do
      doc =
        Org.load_string("""
        #+FILETAGS:   project   work   meta   
        * Section
        """)

      section = Org.section(doc, ["Section"])
      assert Enum.sort(section.tags) == Enum.sort(["project", "work", "meta"])
    end
  end

  describe "complex hierarchies" do
    test "works with deep nesting and multiple branches" do
      doc =
        Org.load_string("""
        #+FILETAGS: global
        * Company :business:
        ** Engineering :tech:
        *** Backend Team :backend:
        **** API Project :api:
        ***** Feature A :feature:
        *** Frontend Team :frontend:
        **** UI Project :ui:
        ** Marketing :marketing:
        *** Campaign :campaign:
        """)

      # Test deep nesting
      feature_a = Org.section(doc, ["Company", "Engineering", "Backend Team", "API Project", "Feature A"])
      expected_feature_tags = ["global", "business", "tech", "backend", "api", "feature"]
      assert Enum.sort(feature_a.tags) == Enum.sort(expected_feature_tags)

      # Test different branch
      ui_project = Org.section(doc, ["Company", "Engineering", "Frontend Team", "UI Project"])
      expected_ui_tags = ["global", "business", "tech", "frontend", "ui"]
      assert Enum.sort(ui_project.tags) == Enum.sort(expected_ui_tags)

      # Test another branch entirely
      campaign = Org.section(doc, ["Company", "Marketing", "Campaign"])
      expected_campaign_tags = ["global", "business", "marketing", "campaign"]
      assert Enum.sort(campaign.tags) == Enum.sort(expected_campaign_tags)
    end
  end

  describe "integration with existing functionality" do
    test "tag inheritance works with todo keywords and priorities" do
      doc =
        Org.load_string("""
        #+FILETAGS: sprint
        * TODO [#A] Epic :feature:
        ** DONE [#B] Task :completed:
        *** TODO Subtask :active:
        """)

      epic = Org.section(doc, ["Epic"])
      task = Org.section(doc, ["Epic", "Task"])
      subtask = Org.section(doc, ["Epic", "Task", "Subtask"])

      # Check that TODO keywords and priorities are preserved
      assert epic.todo_keyword == "TODO"
      assert epic.priority == "A"
      assert task.todo_keyword == "DONE"
      assert task.priority == "B"
      assert subtask.todo_keyword == "TODO"

      # Check tag inheritance
      assert Enum.sort(epic.tags) == Enum.sort(["sprint", "feature"])
      assert Enum.sort(task.tags) == Enum.sort(["sprint", "feature", "completed"])
      assert Enum.sort(subtask.tags) == Enum.sort(["sprint", "feature", "completed", "active"])
    end

    test "serialization includes all effective tags" do
      original_text = """
      #+FILETAGS: global
      * Parent :work:
      ** Child :urgent:
      """

      doc = Org.load_string(original_text)
      serialized = Org.to_org_string(doc)

      # Serialized version should show inherited tags in parentheses and direct tags normally
      assert String.contains?(serialized, "* Parent :(global):work:")
      assert String.contains?(serialized, "** Child :(global):(work):urgent:")

      # When reparsed, should maintain the same effective tags
      reparsed = Org.Parser.parse(serialized, mode: :flexible)
      parent = Org.section(reparsed, ["Parent"])
      child = Org.section(reparsed, ["Parent", "Child"])

      assert "work" in parent.tags
      assert "global" in parent.tags
      assert "urgent" in child.tags
      assert "work" in child.tags
      assert "global" in child.tags
    end
  end
end
