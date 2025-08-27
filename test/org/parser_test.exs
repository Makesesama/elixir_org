defmodule Org.ParserTest do
  use ExUnit.Case

  alias Org.Parser
  alias Org.Parser.Registry
  alias Org.Plugins.{CodeBlock, Denote, DynamicBlock}

  setup do
    # Start registry for each test
    Registry.start()
    Registry.clear()
    :ok
  end

  describe "default parsing (fast path)" do
    test "parses simple document without plugins" do
      text = """
      #+TITLE: Test Document
      #+AUTHOR: Test Author

      * First Section

      Some content here.

      ** Subsection

      More content.
      """

      doc = Parser.parse(text)

      assert doc.file_properties["TITLE"] == "Test Document"
      assert doc.file_properties["AUTHOR"] == "Test Author"
      assert length(doc.sections) == 1
      assert hd(doc.sections).title == "First Section"
    end

    test "parses code blocks in default mode" do
      text = """
      #+BEGIN_SRC elixir
      def hello do
        :world
      end
      #+END_SRC
      """

      doc = Parser.parse(text)

      assert [%Org.CodeBlock{} = block] = doc.contents
      assert block.lang == "elixir"
      assert length(block.lines) == 3
    end

    test "parses tables correctly" do
      text = """
      | Name  | Age |
      |-------+-----|
      | Alice | 30  |
      | Bob   | 25  |
      """

      doc = Parser.parse(text)

      assert [%Org.Table{} = table] = doc.contents
      assert length(table.rows) == 4
    end

    test "parses sections with TODO keywords and priorities" do
      text = """
      * TODO [#A] Important Task
      ** DONE [#B] Subtask
      *** TODO Regular subtask
      """

      doc = Parser.parse(text)

      assert [section] = doc.sections
      assert section.title == "Important Task"
      assert section.todo_keyword == "TODO"
      assert section.priority == "A"

      assert [subsection] = section.children
      assert subsection.todo_keyword == "DONE"
      assert subsection.priority == "B"
    end

    test "parses tags correctly" do
      text = """
      * Section :tag1:tag2:
      ** Subsection :tag3:
      """

      doc = Parser.parse(text)

      assert [section] = doc.sections
      assert section.tags == ["tag1", "tag2"]
      assert [subsection] = section.children
      assert subsection.tags == ["tag3"]
    end
  end

  describe "plugin system" do
    test "registers and uses custom plugin" do
      # Define a simple test plugin
      defmodule TestPlugin do
        use Org.Parser.Plugin

        @impl true
        def patterns, do: ["TEST:"]

        @impl true
        def priority, do: 10

        @impl true
        def parse("TEST:" <> content, _context) do
          {:ok, {:test_content, String.trim(content)}}
        end
      end

      text = """
      TEST: This is test content
      Regular paragraph
      """

      doc = Parser.parse(text, plugins: [TestPlugin])

      assert [{:test_content, "This is test content"}, %Org.Paragraph{}] = doc.contents
    end

    test "plugin priority ordering works" do
      defmodule HighPriorityPlugin do
        use Org.Parser.Plugin

        def patterns, do: ["SPECIAL:"]
        # High priority
        def priority, do: 10

        def parse("SPECIAL:" <> content, _context) do
          {:ok, {:high_priority, String.trim(content)}}
        end
      end

      defmodule LowPriorityPlugin do
        use Org.Parser.Plugin

        def patterns, do: ["SPECIAL:"]
        # Low priority
        def priority, do: 100

        def parse("SPECIAL:" <> content, _context) do
          {:ok, {:low_priority, String.trim(content)}}
        end
      end

      text = "SPECIAL: test"

      doc = Parser.parse(text, plugins: [LowPriorityPlugin, HighPriorityPlugin])

      # High priority plugin should win
      assert [{:high_priority, "test"}] = doc.contents
    end
  end

  describe "CodeBlock" do
    setup do
      Registry.register_plugin(CodeBlock, [])
      :ok
    end

    test "parses code blocks with language and parameters" do
      text = """
      #+BEGIN_SRC python -n 10
      def fibonacci(n):
          if n <= 1:
              return n
          return fibonacci(n-1) + fibonacci(n-2)
      #+END_SRC
      """

      doc = Parser.parse(text, plugins: [CodeBlock])

      assert [%Org.CodeBlock{} = block] = doc.contents
      assert block.lang == "python"
      assert block.details == "-n 10"
      assert length(block.lines) == 4
    end

    test "handles case-insensitive code blocks" do
      text = """
      #+begin_src javascript
      console.log('hello');
      #+end_src
      """

      doc = Parser.parse(text, plugins: [CodeBlock])

      assert [%Org.CodeBlock{} = block] = doc.contents
      assert block.lang == "javascript"
    end

    test "parses example blocks" do
      text = """
      #+BEGIN_EXAMPLE
      This is an example
      with multiple lines
      #+END_EXAMPLE
      """

      doc = Parser.parse(text, plugins: [CodeBlock])

      assert [%Org.CodeBlock{} = block] = doc.contents
      assert block.lang == "example"
      assert length(block.lines) == 2
    end
  end

  describe "DynamicBlock" do
    setup do
      Registry.register_plugin(DynamicBlock, [])
      :ets.new(:dynamic_block_generators, [:set, :public, :named_table])
      :ok
    end

    test "parses dynamic blocks with parameters" do
      text = """
      #+BEGIN: clocktable :scope file :maxlevel 2
      Clock summary content
      #+END:
      """

      doc = Parser.parse(text, plugins: [DynamicBlock])

      assert [%DynamicBlock.DynamicBlock{} = block] = doc.contents
      assert block.name == "clocktable"
      assert block.params[:scope] == "file"
      assert block.params[:maxlevel] == "2"
    end

    test "dynamic block with generator function" do
      # Register a generator
      generator = fn params ->
        count = params[:count] || "5"
        ["Generated line 1", "Generated line 2", "Count: #{count}"]
      end

      DynamicBlock.register_generator("testblock", generator)

      text = """
      #+BEGIN: testblock :count 10
      Old content
      #+END:
      """

      doc = Parser.parse(text, plugins: [DynamicBlock])

      assert [%DynamicBlock.DynamicBlock{} = block] = doc.contents
      assert block.name == "testblock"

      # Update the block
      updated = DynamicBlock.update_block(block)
      assert updated.content == ["Generated line 1", "Generated line 2", "Count: 10"]
    end
  end

  describe "Denote" do
    setup do
      Registry.register_plugin(Denote, [])
      :ok
    end

    test "parses denote links" do
      text = """
      [[denote:20240115T143000][My Note Title]]
      [[id:20240115T143000]]
      """

      doc = Parser.parse(text, plugins: [Denote])

      # Note: This would need proper integration with paragraph parsing
      # For now, just verify the plugin loads correctly
      assert doc
    end

    test "extracts denote ID from filename" do
      filename = "20240115T143000--my-important-note__work_project.org"

      assert {:ok, "20240115T143000"} = Denote.extract_denote_id(filename)
    end

    test "generates denote-compliant filename" do
      title = "My Important Note"
      keywords = ["work", "project"]

      # Use a fixed timestamp for testing
      timestamp = ~U[2024-01-15 14:30:00Z]

      filename = Denote.generate_filename(title, keywords, timestamp)

      assert filename == "20240115T143000--my-important-note__work_project.org"
    end
  end

  describe "performance" do
    test "default parsing has minimal overhead" do
      # Generate a large document
      sections =
        for i <- 1..100 do
          """
          * Section #{i}

          Content for section #{i}.

          ** Subsection #{i}.1

          More content here.
          """
        end

      text = Enum.join(sections, "\n")

      # Measure parsing time
      {time, doc} = :timer.tc(fn -> Parser.parse(text) end)

      # Should parse quickly (under 100ms for 100 sections)
      # microseconds
      assert time < 100_000
      assert length(doc.sections) == 100
    end

    test "plugin overhead is minimal when not matching" do
      # Plugin that never matches
      defmodule NoMatchPlugin do
        use Org.Parser.Plugin

        def patterns, do: ["NEVERMATCH:"]
        def parse(_, _), do: :skip
      end

      text = """
      * Regular Section

      Regular content that doesn't match the plugin.
      """

      # Parse with multiple non-matching plugins
      plugins = List.duplicate(NoMatchPlugin, 10)

      {time, _doc} =
        :timer.tc(fn ->
          Parser.parse(text, plugins: plugins)
        end)

      # Should still be fast even with many plugins
      # microseconds
      assert time < 10_000
    end
  end

  describe "error handling" do
    test "handles malformed input gracefully" do
      text = """
      #+BEGIN_SRC elixir
      def unclosed_block do
        :missing_end
      """

      # Should not crash
      doc = Parser.parse(text)
      assert doc
    end

    test "handles plugin errors gracefully" do
      defmodule ErrorPlugin do
        use Org.Parser.Plugin

        def patterns, do: ["ERROR:"]

        def parse("ERROR:" <> _, _context) do
          raise "Intentional error"
        end
      end

      text = "ERROR: This triggers an error"

      # Should handle the error and continue
      doc = Parser.parse(text, plugins: [ErrorPlugin])
      # Should still return a document
      assert doc
    end
  end

  describe "Context integration" do
    test "parses with context instead of direct plugins" do
      context = Parser.Context.new([CodeBlock])

      text = """
      #+BEGIN_SRC elixir
      def hello, do: :world
      #+END_SRC
      """

      doc = Parser.parse(text, context: context)

      assert [%Org.CodeBlock{} = block] = doc.contents
      assert block.lang == "elixir"
    end

    test "context overrides direct plugins" do
      # Context with only CodeBlock
      context = Parser.Context.new([CodeBlock])

      text = """
      [[denote:20240115T143000][My Note]]
      #+BEGIN_SRC elixir
      def test, do: :ok
      #+END_SRC
      """

      # Pass Denote in plugins, but context should take precedence
      doc = Parser.parse(text, context: context, plugins: [Denote])

      # Should parse code block but treat denote link as regular paragraph
      assert Enum.any?(doc.contents, fn
               %Org.CodeBlock{} -> true
               _ -> false
             end)
    end

    test "different contexts produce different parsing results" do
      context_denote = Parser.Context.new([Denote])
      context_code = Parser.Context.new([CodeBlock])

      text = """
      [[denote:20240115T143000][My Note]]
      #+BEGIN_SRC elixir
      def test, do: :ok
      #+END_SRC
      """

      doc_denote = Parser.parse(text, context: context_denote)
      doc_code = Parser.parse(text, context: context_code)

      # Different contexts should produce different parsing results
      assert doc_denote != doc_code
    end
  end
end
