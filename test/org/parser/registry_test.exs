defmodule Org.Parser.RegistryTest do
  use ExUnit.Case

  alias Org.Parser.Registry

  defmodule TestPlugin do
    use Org.Parser.Plugin

    @impl true
    def patterns, do: ["TEST:", ~r/^REGEX:/]

    @impl true
    def priority, do: 50

    @impl true
    def parse(content, _context) do
      {:ok, {:test_result, content}}
    end

    @impl true
    def init(opts) do
      {:ok, Keyword.get(opts, :test_state, :default)}
    end
  end

  defmodule AnotherPlugin do
    use Org.Parser.Plugin

    @impl true
    def patterns, do: ["ANOTHER:"]

    @impl true
    def priority, do: 100

    @impl true
    def parse(_content, _context), do: :skip
  end

  defmodule HighPriorityPlugin do
    use Org.Parser.Plugin

    @impl true
    def patterns, do: ["TEST:"]

    @impl true
    # Higher priority
    def priority, do: 10

    @impl true
    def parse(_content, _context), do: :skip
  end

  setup do
    Registry.start()
    Registry.clear()
    :ok
  end

  describe "registry operations" do
    test "start/0 creates ETS tables" do
      Registry.start()

      # Tables should exist
      assert :ets.info(:org_parser_plugins) != :undefined
      assert :ets.info(:org_parser_patterns) != :undefined
    end

    test "register_plugin/2 stores plugin info" do
      assert :ok = Registry.register_plugin(TestPlugin, test_state: :custom)

      # Plugin should be listed
      assert TestPlugin in Registry.list_plugins()

      # State should be accessible
      assert Registry.get_plugin_state(TestPlugin) == :custom
    end

    test "register_plugin/2 validates plugin module" do
      defmodule InvalidPlugin do
        # Missing required callbacks
      end

      assert {:error, {:invalid_plugin, InvalidPlugin}} =
               Registry.register_plugin(InvalidPlugin, [])
    end

    test "get_plugins_for/1 returns matching plugins" do
      Registry.register_plugin(TestPlugin, [])
      Registry.register_plugin(AnotherPlugin, [])

      # Should find matching plugin
      plugins = Registry.get_plugins_for("TEST: some content")
      assert TestPlugin in plugins
      assert AnotherPlugin not in plugins

      # Should find other plugin
      plugins = Registry.get_plugins_for("ANOTHER: different content")
      assert AnotherPlugin in plugins
      assert TestPlugin not in plugins
    end

    test "get_plugins_for/1 handles regex patterns" do
      Registry.register_plugin(TestPlugin, [])

      plugins = Registry.get_plugins_for("REGEX: this matches regex")
      assert TestPlugin in plugins
    end

    test "plugins are returned in priority order" do
      # priority 50
      Registry.register_plugin(TestPlugin, [])
      # priority 10
      Registry.register_plugin(HighPriorityPlugin, [])

      plugins = Registry.get_plugins_for("TEST: content")

      # Higher priority (lower number) should come first
      assert plugins == [HighPriorityPlugin, TestPlugin]
    end

    test "clear/0 removes all plugins" do
      Registry.register_plugin(TestPlugin, [])
      Registry.register_plugin(AnotherPlugin, [])

      assert length(Registry.list_plugins()) == 2

      Registry.clear()

      assert Registry.list_plugins() == []
    end
  end

  describe "pattern matching performance" do
    setup do
      Registry.start()
      Registry.clear()
      :ok
    end

    test "fast lookup with many plugins" do
      # Register many plugins with different patterns
      plugins =
        for i <- 1..100 do
          pattern = "PATTERN#{i}:"

          plugin =
            quote do
              defmodule unquote(Module.concat(TestPlugins, "Plugin#{i}")) do
                use Org.Parser.Plugin

                def patterns, do: [unquote(pattern)]
                def priority, do: unquote(i)
                def parse(_, _), do: :skip
              end
            end

          Code.eval_quoted(plugin)
          Module.concat(TestPlugins, "Plugin#{i}")
        end

      # Register all plugins
      Enum.each(plugins, fn plugin ->
        Registry.register_plugin(plugin, [])
      end)

      # Lookup should still be fast
      {time, result} =
        :timer.tc(fn ->
          Registry.get_plugins_for("PATTERN50: test content")
        end)

      # Should find the right plugin
      target_plugin = Module.concat(TestPlugins, "Plugin50")
      assert target_plugin in result

      # Should be fast (under 1ms)
      # microseconds
      assert time < 1_000
    end

    test "handles content that doesn't match any patterns" do
      Registry.register_plugin(TestPlugin, [])

      plugins = Registry.get_plugins_for("NO MATCH: content")
      assert plugins == []
    end

    test "handles empty content" do
      Registry.register_plugin(TestPlugin, [])

      plugins = Registry.get_plugins_for("")
      assert plugins == []
    end
  end

  describe "fast_match? optimization" do
    defmodule FastMatchPlugin do
      use Org.Parser.Plugin

      def patterns, do: ["FAST:"]
      def priority, do: 50
      def parse(_, _), do: :skip

      # Custom fast_match? implementation
      def fast_match?(<<"FAST:", _::binary>>), do: true
      def fast_match?(_), do: false
    end

    test "uses fast_match? when available" do
      Registry.register_plugin(FastMatchPlugin, [])

      # Should match
      plugins = Registry.get_plugins_for("FAST: content")
      assert FastMatchPlugin in plugins

      # Should not match due to fast_match? returning false
      plugins = Registry.get_plugins_for("SLOW: content")
      assert FastMatchPlugin not in plugins
    end
  end

  describe "concurrent access" do
    test "supports concurrent reads" do
      Registry.register_plugin(TestPlugin, [])

      # Spawn multiple processes doing lookups
      tasks =
        for _i <- 1..10 do
          Task.async(fn ->
            Registry.get_plugins_for("TEST: concurrent access")
          end)
        end

      results = Task.await_many(tasks)

      # All should return the same result
      expected = [TestPlugin]
      assert Enum.all?(results, fn result -> result == expected end)
    end

    test "supports concurrent writes" do
      # Create multiple plugins concurrently
      plugins =
        for i <- 1..5 do
          plugin =
            quote do
              defmodule unquote(Module.concat(ConcurrentPlugins, "Plugin#{i}")) do
                use Org.Parser.Plugin

                def patterns, do: [unquote("CONCURRENT#{i}:")]
                def priority, do: unquote(i * 10)
                def parse(_, _), do: :skip
              end
            end

          Code.eval_quoted(plugin)
          Module.concat(ConcurrentPlugins, "Plugin#{i}")
        end

      # Register them concurrently
      tasks =
        Enum.map(plugins, fn plugin ->
          Task.async(fn ->
            Registry.register_plugin(plugin, [])
          end)
        end)

      results = Task.await_many(tasks)

      # All registrations should succeed
      assert Enum.all?(results, fn result -> result == :ok end)

      # All plugins should be registered
      registered = Registry.list_plugins()
      assert length(registered) == 5

      Enum.each(plugins, fn plugin ->
        assert plugin in registered
      end)
    end
  end
end
