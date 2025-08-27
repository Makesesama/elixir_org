defmodule RegistryVsDirectBenchmark do
  @moduledoc """
  Benchmark comparing registry-based plugin lookup vs direct plugin usage.
  """

  alias Org.Parser
  alias Org.Parser.Registry
  alias Org.Plugins.{CodeBlock, Denote, DynamicBlock}

  def run do
    # Test content with various patterns
    test_content = """
    #+TITLE: Test Document
    #+BEGIN_SRC elixir
    def test, do: :ok
    #+END_SRC

    [[denote:20240115T144532][My Note]]

    * Section
    Regular paragraph content.
    """

    # Benchmark data structures
    plugins = [Denote, CodeBlock, DynamicBlock]
    iterations = 1000

    IO.puts("Registry vs Direct Plugin Performance Benchmark")
    IO.puts("=" <> String.duplicate("=", 48))
    IO.puts("Iterations: #{iterations}")
    IO.puts("Content length: #{String.length(test_content)} bytes")
    IO.puts("")

    # Setup registry
    Registry.start()
    Registry.clear()

    Enum.each(plugins, fn plugin ->
      Registry.register_plugin(plugin, [])
    end)

    # Benchmark registry approach
    {registry_time, _} =
      :timer.tc(fn ->
        for _ <- 1..iterations do
          # Uses registry automatically
          Parser.parse(test_content)
        end
      end)

    # Benchmark direct plugin approach
    {direct_time, _} =
      :timer.tc(fn ->
        for _ <- 1..iterations do
          Parser.parse(test_content, plugins: plugins)
        end
      end)

    # Benchmark no plugins (baseline)
    {baseline_time, _} =
      :timer.tc(fn ->
        for _ <- 1..iterations do
          Parser.parse(test_content, plugins: [])
        end
      end)

    # Results
    registry_ms = registry_time / 1000
    direct_ms = direct_time / 1000
    baseline_ms = baseline_time / 1000

    registry_per_parse = registry_ms / iterations
    direct_per_parse = direct_ms / iterations
    baseline_per_parse = baseline_ms / iterations

    IO.puts("Results:")
    IO.puts("--------")

    IO.puts(
      "Baseline (no plugins):   #{:io_lib.format("~8.2f", [baseline_ms])} ms total (#{:io_lib.format("~6.3f", [baseline_per_parse])} ms/parse)"
    )

    IO.puts(
      "Registry approach:       #{:io_lib.format("~8.2f", [registry_ms])} ms total (#{:io_lib.format("~6.3f", [registry_per_parse])} ms/parse)"
    )

    IO.puts(
      "Direct plugins:          #{:io_lib.format("~8.2f", [direct_ms])} ms total (#{:io_lib.format("~6.3f", [direct_per_parse])} ms/parse)"
    )

    IO.puts("")

    registry_overhead = (registry_ms - baseline_ms) / baseline_ms * 100
    direct_overhead = (direct_ms - baseline_ms) / baseline_ms * 100

    IO.puts("Plugin overhead:")
    IO.puts("Registry:  #{:io_lib.format("~6.1f", [registry_overhead])}% slower than baseline")
    IO.puts("Direct:    #{:io_lib.format("~6.1f", [direct_overhead])}% slower than baseline")
    IO.puts("")

    if registry_ms < direct_ms do
      speedup = (direct_ms / registry_ms - 1) * 100
      IO.puts("Registry is #{:io_lib.format("~.1f", [speedup])}% faster than direct plugins")
    else
      slowdown = (registry_ms / direct_ms - 1) * 100
      IO.puts("Registry is #{:io_lib.format("~.1f", [slowdown])}% slower than direct plugins")
    end

    # Memory usage test (rough estimation)
    IO.puts("")
    IO.puts("Memory Usage (rough estimation):")
    IO.puts("-" <> String.duplicate("-", 33))

    # Test memory usage with many plugins
    many_plugins = create_test_plugins(50)

    # Setup registry with many plugins
    Registry.clear()

    Enum.each(many_plugins, fn plugin ->
      Registry.register_plugin(plugin, [])
    end)

    {reg_time_many, _} =
      :timer.tc(fn ->
        for _ <- 1..100 do
          Parser.parse("* Test Section\nSome content.")
        end
      end)

    {direct_time_many, _} =
      :timer.tc(fn ->
        for _ <- 1..100 do
          Parser.parse("* Test Section\nSome content.", plugins: many_plugins)
        end
      end)

    reg_ms_many = reg_time_many / 1000
    direct_ms_many = direct_time_many / 1000

    IO.puts("With 50 plugins:")
    IO.puts("Registry: #{:io_lib.format("~8.2f", [reg_ms_many])} ms (100 parses)")
    IO.puts("Direct:   #{:io_lib.format("~8.2f", [direct_ms_many])} ms (100 parses)")

    if reg_ms_many < direct_ms_many do
      speedup_many = (direct_ms_many / reg_ms_many - 1) * 100
      IO.puts("Registry is #{:io_lib.format("~.1f", [speedup_many])}% faster with many plugins")
    end
  end

  # Create test plugins for benchmarking
  defp create_test_plugins(count) do
    for i <- 1..count do
      plugin_name = Module.concat(TestPlugins, "Plugin#{i}")

      plugin_code =
        quote do
          defmodule unquote(plugin_name) do
            use Org.Parser.Plugin

            @impl true
            def patterns, do: ["TESTPATTERN#{unquote(i)}:"]

            @impl true
            def priority, do: unquote(i * 10)

            @impl true
            def parse(_content, _context), do: :skip

            @impl true
            def init(_opts), do: {:ok, %{}}
          end
        end

      Code.eval_quoted(plugin_code)
      plugin_name
    end
  end
end

# Run the benchmark
RegistryVsDirectBenchmark.run()
