# Parser Performance Benchmark
#
# Run with: mix run benchmark/parser_benchmark.exs

defmodule ParserBenchmark do
  @moduledoc """
  Benchmarks for comparing parser performance:
  - Default parsing vs plugin parsing
  - Various document sizes and complexities
  - Plugin overhead analysis
  """

  alias Org.Parser
  alias Org.Parser.Registry
  alias Org.Plugins.{CodeBlock, Denote, DynamicBlock}

  def run do
    IO.puts("Org Parser Performance Benchmark")
    IO.puts("=================================\n")

    # Setup
    Registry.start()
    Registry.register_plugin(CodeBlock, [])
    Registry.register_plugin(DynamicBlock, [])

    # Test documents of various sizes
    small_doc = generate_document(10)
    medium_doc = generate_document(100)
    large_doc = generate_document(1000)

    # Run benchmarks
    benchmark_parsing_modes(small_doc, "Small Document (10 sections)")
    benchmark_parsing_modes(medium_doc, "Medium Document (100 sections)")
    benchmark_parsing_modes(large_doc, "Large Document (1000 sections)")

    benchmark_plugin_overhead()
    benchmark_pattern_matching()

    IO.puts("\nBenchmark completed!")
  end

  defp benchmark_parsing_modes(document, label) do
    IO.puts("#{label}")
    IO.puts(String.duplicate("-", String.length(label)))

    # Parser without plugins
    {time_default, result_default} = :timer.tc(fn -> Parser.parse(document) end)
    IO.puts("Parser (no plugins):     #{format_time(time_default)}")

    # Parser with basic plugins
    {time_basic_plugins, _result_basic} =
      :timer.tc(fn ->
        Parser.parse(document, plugins: [CodeBlock, DynamicBlock])
      end)

    IO.puts("Parser (basic plugins):  #{format_time(time_basic_plugins)}")

    # Parser with all plugins including Denote
    {time_all_plugins, _result_all} =
      :timer.tc(fn ->
        Parser.parse(document, plugins: [CodeBlock, DynamicBlock, Denote])
      end)

    IO.puts("Parser (all plugins):    #{format_time(time_all_plugins)}")

    # Calculate overhead
    basic_overhead = time_basic_plugins / time_default
    all_overhead = time_all_plugins / time_default

    IO.puts("Basic plugin overhead:   #{Float.round(basic_overhead, 2)}x")
    IO.puts("All plugin overhead:     #{Float.round(all_overhead, 2)}x")

    # Content comparison
    sections_count = length(result_default.sections)
    IO.puts("Sections parsed:         #{sections_count}")
    IO.puts("")
  end

  defp benchmark_plugin_overhead do
    IO.puts("Plugin Overhead Analysis")
    IO.puts("-------------------------")

    document = generate_simple_document()

    # No plugins
    {time_no_plugins, _} = :timer.tc(fn -> Parser.parse(document) end)

    # With plugins that never match
    non_matching_plugins = [
      create_dummy_plugin("NEVER1:"),
      create_dummy_plugin("NEVER2:"),
      create_dummy_plugin("NEVER3:")
    ]

    {time_non_matching, _} =
      :timer.tc(fn ->
        Parser.parse(document, plugins: non_matching_plugins)
      end)

    # With plugins that do match (including our new Denote plugin)
    matching_plugins = [CodeBlock, DynamicBlock, Denote]

    {time_matching, _} =
      :timer.tc(fn ->
        Parser.parse(document, plugins: matching_plugins)
      end)

    IO.puts("No plugins:           #{format_time(time_no_plugins)}")
    IO.puts("Non-matching plugins: #{format_time(time_non_matching)}")
    IO.puts("Matching plugins:     #{format_time(time_matching)}")

    overhead_non_matching = time_non_matching / time_no_plugins
    overhead_matching = time_matching / time_no_plugins

    IO.puts("Non-matching overhead: #{Float.round(overhead_non_matching, 2)}x")
    IO.puts("Matching overhead:     #{Float.round(overhead_matching, 2)}x")
    IO.puts("")
  end

  defp benchmark_pattern_matching do
    IO.puts("Pattern Matching Performance")
    IO.puts("-----------------------------")

    # Setup many plugins
    plugins =
      for i <- 1..100 do
        create_dummy_plugin("PATTERN#{i}:")
      end

    Enum.each(plugins, fn plugin ->
      Registry.register_plugin(plugin, [])
    end)

    # Test lookup performance
    {time_lookup, _plugins} =
      :timer.tc(fn ->
        Registry.get_plugins_for("PATTERN50: test content")
      end)

    {time_no_match, _} =
      :timer.tc(fn ->
        Registry.get_plugins_for("NOMATCH: test content")
      end)

    IO.puts("Plugin lookup (match):    #{format_time(time_lookup)}")
    IO.puts("Plugin lookup (no match): #{format_time(time_no_match)}")
    IO.puts("")

    Registry.clear()
  end

  defp create_dummy_plugin(pattern) do
    # Create unique module name
    module_name = String.to_atom("DummyPlugin#{:crypto.strong_rand_bytes(4) |> Base.encode16()}")

    # Create plugin module dynamically
    plugin_module =
      quote do
        defmodule unquote(module_name) do
          use Org.Parser.Plugin

          def patterns, do: [unquote(pattern)]
          def priority, do: 100
          def parse(_, _), do: :skip
        end
      end

    Code.eval_quoted(plugin_module)
    module_name
  end

  defp generate_document(num_sections) do
    sections =
      for i <- 1..num_sections do
        level = rem(i, 3) + 1
        stars = String.duplicate("*", level)

        """
        #{stars} Section #{i}

        This is content for section #{i}. It contains some text
        and demonstrates the parsing performance.

        #+BEGIN_SRC elixir
        def section_#{i}() do
          :section_content
        end
        #+END_SRC
        """
      end

    header = """
    #+TITLE: Performance Test Document
    #+AUTHOR: Benchmark Runner
    #+DATE: #{Date.utc_today()}

    This document is used for performance testing.

    """

    header <> Enum.join(sections, "\n\n")
  end

  defp generate_simple_document do
    """
    #+TITLE: Simple Document

    * First Section

    Some simple content here.

    * Second Section

    More content.
    """
  end

  defp format_time(microseconds) when microseconds < 1_000 do
    "#{microseconds}μs"
  end

  defp format_time(microseconds) when microseconds < 1_000_000 do
    ms = Float.round(microseconds / 1_000, 2)
    "#{ms}ms"
  end

  defp format_time(microseconds) do
    s = Float.round(microseconds / 1_000_000, 2)
    "#{s}s"
  end
end

# Run the benchmark
ParserBenchmark.run()
