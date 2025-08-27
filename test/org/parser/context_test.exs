defmodule Org.Parser.ContextTest do
  use ExUnit.Case

  alias Org.Parser
  alias Org.Parser.Context
  alias Org.Plugins.{CodeBlock, Denote, DynamicBlock}

  describe "Context.new/2" do
    test "creates context with plugins" do
      plugins = [Denote, CodeBlock]
      context = Context.new(plugins)

      assert context.plugins == plugins
      assert is_map(context.pattern_map)
      assert is_list(context.priority_sorted_plugins)
      assert is_map(context.plugin_states)
      assert %DateTime{} = context.compiled_at
    end

    test "initializes plugin states" do
      plugins = [Denote]
      context = Context.new(plugins)

      assert Map.has_key?(context.plugin_states, Denote)
    end

    test "sorts plugins by priority" do
      # Create test plugins with different priorities
      defmodule HighPriorityPlugin do
        use Org.Parser.Plugin
        def patterns, do: ["HIGH:"]
        def priority, do: 10
        def parse(_, _), do: :skip
      end

      defmodule LowPriorityPlugin do
        use Org.Parser.Plugin
        def patterns, do: ["LOW:"]
        def priority, do: 100
        def parse(_, _), do: :skip
      end

      plugins = [LowPriorityPlugin, HighPriorityPlugin]
      context = Context.new(plugins)

      assert context.priority_sorted_plugins == [HighPriorityPlugin, LowPriorityPlugin]
    end
  end

  describe "Context.get_matching_plugins/2" do
    setup do
      plugins = [Denote, CodeBlock]
      context = Context.new(plugins)
      {:ok, context: context}
    end

    test "returns matching plugins for Denote links", %{context: context} do
      matching = Context.get_matching_plugins(context, "[[denote:20240115T144532][Note]]")
      assert Denote in matching
    end

    test "returns matching plugins for code blocks", %{context: context} do
      matching = Context.get_matching_plugins(context, "#+BEGIN_SRC elixir")
      assert CodeBlock in matching
    end

    test "returns empty list for non-matching content", %{context: context} do
      matching = Context.get_matching_plugins(context, "Regular paragraph")
      assert matching == []
    end

    test "returns plugins in priority order", %{context: context} do
      # Both plugins might match certain patterns, ensure priority order
      matching = Context.get_matching_plugins(context, "#+BEGIN_SRC elixir")
      # CodeBlock should come first due to priority
      assert hd(matching) == CodeBlock
    end
  end

  describe "Context plugin state management" do
    test "get_plugin_state/2 returns plugin state" do
      context = Context.new([Denote])
      state = Context.get_plugin_state(context, Denote)
      assert is_map(state)
    end

    test "put_plugin_state/3 updates plugin state" do
      context = Context.new([Denote])
      new_state = %{test: :value}

      updated_context = Context.put_plugin_state(context, Denote, new_state)

      assert Context.get_plugin_state(updated_context, Denote) == new_state
      # Original context unchanged
      refute Context.get_plugin_state(context, Denote) == new_state
    end

    test "has_plugin?/2 checks plugin presence" do
      context = Context.new([Denote, CodeBlock])

      assert Context.has_plugin?(context, Denote)
      assert Context.has_plugin?(context, CodeBlock)
      refute Context.has_plugin?(context, DynamicBlock)
    end
  end

  describe "Parser integration with Context" do
    test "parses with user context" do
      context = Context.new([CodeBlock])

      content = """
      #+BEGIN_SRC elixir
      def test, do: :ok
      #+END_SRC
      """

      doc = Parser.parse(content, context: context)

      assert doc
      # Should have parsed the code block
      assert length(doc.contents) > 0
    end

    test "different contexts produce different results" do
      context_with_denote = Context.new([Denote])
      context_without_denote = Context.new([CodeBlock])

      content = """
      [[denote:20240115T144532][My Note]]
      """

      doc_with = Parser.parse(content, context: context_with_denote)
      doc_without = Parser.parse(content, context: context_without_denote)

      # Results should be different based on available plugins
      assert doc_with != doc_without
    end

    test "user context takes precedence over direct plugins" do
      context = Context.new([CodeBlock])

      content = """
      #+BEGIN_SRC elixir
      def test, do: :ok
      #+END_SRC
      """

      # Even if we pass different plugins directly, user_context should be used
      doc =
        Parser.parse(content,
          context: context,
          # This should be ignored
          plugins: [Denote]
        )

      assert doc
    end
  end

  describe "performance characteristics" do
    test "context creation is reasonably fast" do
      plugins = [Denote, CodeBlock, DynamicBlock]

      {time, _context} =
        :timer.tc(fn ->
          Context.new(plugins)
        end)

      # Should create context in under 10ms
      assert time < 10_000
    end

    test "plugin lookup is fast with many patterns" do
      # Create context with multiple plugins
      plugins = [Denote, CodeBlock, DynamicBlock]
      context = Context.new(plugins)

      content = "[[denote:123][Test]]"

      {time, _matching} =
        :timer.tc(fn ->
          for _ <- 1..1000 do
            Context.get_matching_plugins(context, content)
          end
        end)

      # Should handle 1000 lookups in under 10ms
      assert time < 10_000
    end
  end

  describe "memory efficiency" do
    test "contexts are reasonably sized" do
      plugins = [Denote, CodeBlock]
      context = Context.new(plugins)

      # Context should not be excessively large
      context_size = :erts_debug.size(context)
      # words
      assert context_size < 1000
    end

    test "multiple contexts don't interfere" do
      context1 = Context.new([Denote])
      context2 = Context.new([CodeBlock])

      # Updating one context shouldn't affect the other
      updated_context1 = Context.put_plugin_state(context1, Denote, %{updated: true})

      assert Context.get_plugin_state(updated_context1, Denote).updated
      refute Map.has_key?(Context.get_plugin_state(context1, Denote), :updated)

      # context2 completely unaffected
      refute Context.has_plugin?(context2, Denote)
    end
  end
end
