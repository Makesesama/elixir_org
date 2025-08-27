defmodule ContextBenchmark do
  @moduledoc """
  Benchmark comparing context vs direct plugins vs registry for per-user scenarios.
  """

  alias Org.Parser
  alias Org.Parser.{Context, Registry}
  alias Org.Plugins.{CodeBlock, Denote, DynamicBlock}

  def run do
    # Test content with various patterns
    test_content = """
    #+TITLE: User Specific Document
    #+BEGIN_SRC elixir
    def user_function, do: :ok
    #+END_SRC

    [[denote:20240115T144532][User Note]]

    * User Section
    User specific content here.
    """

    plugins = [Denote, CodeBlock, DynamicBlock]
    iterations = 500

    IO.puts("Context vs Direct Plugins vs Registry Performance")
    IO.puts("=" <> String.duplicate("=", 47))
    IO.puts("Iterations: #{iterations}")
    IO.puts("Content length: #{String.length(test_content)} bytes")
    IO.puts("")

    # Benchmark 1: Direct plugins (current approach)
    {direct_time, _} =
      :timer.tc(fn ->
        for _ <- 1..iterations do
          Parser.parse(test_content, plugins: plugins)
        end
      end)

    # Benchmark 2: Context (new approach)
    context = Context.new(plugins)

    {context_time, _} =
      :timer.tc(fn ->
        for _ <- 1..iterations do
          Parser.parse(test_content, context: context)
        end
      end)

    # Benchmark 3: Registry (global approach)
    Registry.start()
    Registry.clear()

    Enum.each(plugins, fn plugin ->
      Registry.register_plugin(plugin, [])
    end)

    {registry_time, _} =
      :timer.tc(fn ->
        for _ <- 1..iterations do
          # Uses global registry
          Parser.parse(test_content)
        end
      end)

    # Results
    direct_ms = direct_time / 1000
    context_ms = context_time / 1000
    registry_ms = registry_time / 1000

    direct_per_parse = direct_ms / iterations
    context_per_parse = context_ms / iterations
    registry_per_parse = registry_ms / iterations

    IO.puts("Results:")
    IO.puts("--------")

    IO.puts(
      "Direct plugins:  #{:io_lib.format("~8.2f", [direct_ms])} ms total (#{:io_lib.format("~6.3f", [direct_per_parse])} ms/parse)"
    )

    IO.puts(
      "Context:         #{:io_lib.format("~8.2f", [context_ms])} ms total (#{:io_lib.format("~6.3f", [context_per_parse])} ms/parse)"
    )

    IO.puts(
      "Registry:        #{:io_lib.format("~8.2f", [registry_ms])} ms total (#{:io_lib.format("~6.3f", [registry_per_parse])} ms/parse)"
    )

    IO.puts("")

    # Compare user context to direct plugins
    if context_ms < direct_ms do
      speedup = (direct_ms / context_ms - 1) * 100
      IO.puts("Context is #{:io_lib.format("~.1f", [speedup])}% faster than direct plugins")
    else
      slowdown = (context_ms / direct_ms - 1) * 100
      IO.puts("Context is #{:io_lib.format("~.1f", [slowdown])}% slower than direct plugins")
    end

    # Compare user context to registry
    if context_ms < registry_ms do
      vs_registry = (registry_ms / context_ms - 1) * 100
      IO.puts("Context is #{:io_lib.format("~.1f", [vs_registry])}% faster than registry")
    else
      vs_registry = (context_ms / registry_ms - 1) * 100
      IO.puts("Context is #{:io_lib.format("~.1f", [vs_registry])}% slower than registry")
    end

    IO.puts("")

    # Multi-user scenario test
    IO.puts("Multi-User Scenario Test:")
    IO.puts("-" <> String.duplicate("-", 25))

    # Create different user contexts
    user1_plugins = [Denote, CodeBlock]
    user2_plugins = [CodeBlock, DynamicBlock]
    user3_plugins = [Denote, DynamicBlock]

    user1_context = Context.new(user1_plugins)
    user2_context = Context.new(user2_plugins)
    user3_context = Context.new(user3_plugins)

    # Benchmark multi-user with contexts
    {multi_context_time, _} =
      :timer.tc(fn ->
        for _ <- 1..100 do
          Parser.parse(test_content, context: user1_context)
          Parser.parse(test_content, context: user2_context)
          Parser.parse(test_content, context: user3_context)
        end
      end)

    # Benchmark multi-user with direct plugins (simulating different users)
    {multi_direct_time, _} =
      :timer.tc(fn ->
        for _ <- 1..100 do
          Parser.parse(test_content, plugins: user1_plugins)
          Parser.parse(test_content, plugins: user2_plugins)
          Parser.parse(test_content, plugins: user3_plugins)
        end
      end)

    multi_context_ms = multi_context_time / 1000
    multi_direct_ms = multi_direct_time / 1000

    IO.puts("Multi-user (300 parses, 3 users, different plugins):")
    IO.puts("Contexts: #{:io_lib.format("~8.2f", [multi_context_ms])} ms")
    IO.puts("Direct plugins: #{:io_lib.format("~8.2f", [multi_direct_ms])} ms")

    if multi_context_ms < multi_direct_ms do
      multi_speedup = (multi_direct_ms / multi_context_ms - 1) * 100
      IO.puts("Contexts are #{:io_lib.format("~.1f", [multi_speedup])}% faster in multi-user scenarios")
    end

    # Memory usage comparison
    IO.puts("")
    IO.puts("Memory Characteristics:")
    IO.puts("-" <> String.duplicate("-", 23))

    context_size = :erts_debug.size(context)
    plugins_size = :erts_debug.size(plugins)

    IO.puts("Context memory: ~#{context_size} words")
    IO.puts("Plugin list memory:  ~#{plugins_size} words")
    IO.puts("Context overhead:    ~#{context_size - plugins_size} words (pattern compilation)")

    IO.puts("")
    IO.puts("Recommendations:")
    IO.puts("- Use Context for per-user plugin configurations")
    IO.puts("- Use Registry only for global/shared plugin sets")
    speedup_pct = trunc((direct_ms / context_ms - 1) * 100)
    IO.puts("- Context trades memory for speed (#{context_size}x memory, ~#{speedup_pct}% faster)")
  end
end

# Run the benchmark
ContextBenchmark.run()
