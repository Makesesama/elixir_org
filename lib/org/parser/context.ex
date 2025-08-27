defmodule Org.Parser.Context do
  @moduledoc """
  Plugin context that provides registry-like performance without global state.

  This allows different contexts to have different plugin configurations while
  maintaining the performance benefits of pre-compiled pattern matching.

  ## Usage

      # Create context with specific plugins
      context = Org.Parser.Context.new([
        Org.Plugins.Denote,
        Org.Plugins.CodeBlock
      ])
      
      # Parse with context
      doc = Org.Parser.parse(content, context: context)
      
      # Reuse context for subsequent parses (very fast)
      doc2 = Org.Parser.parse(content2, context: context)
  """

  defstruct [
    :plugins,
    :pattern_map,
    :priority_sorted_plugins,
    :plugin_states,
    :compiled_at
  ]

  @type t :: %__MODULE__{
          plugins: [module()],
          pattern_map: %{binary() => [module()]},
          priority_sorted_plugins: [module()],
          plugin_states: %{module() => term()},
          compiled_at: DateTime.t()
        }

  @doc """
  Create a new user context with the specified plugins.

  This pre-compiles all patterns for fast lookup during parsing.
  """
  @spec new([module()], keyword()) :: t()
  def new(plugins, opts \\ []) do
    # Initialize all plugins
    plugin_states =
      Enum.reduce(plugins, %{}, fn plugin, acc ->
        case plugin.init(opts) do
          {:ok, state} -> Map.put(acc, plugin, state)
          _ -> Map.put(acc, plugin, %{})
        end
      end)

    # Build pattern lookup map
    pattern_map = build_pattern_map(plugins)

    # Sort plugins by priority
    priority_sorted = Enum.sort_by(plugins, & &1.priority())

    %__MODULE__{
      plugins: plugins,
      pattern_map: pattern_map,
      priority_sorted_plugins: priority_sorted,
      plugin_states: plugin_states,
      compiled_at: DateTime.utc_now()
    }
  end

  @doc """
  Get plugins that match the given content, sorted by priority.

  This is the performance-critical function that should be as fast as ETS lookup.
  """
  @spec get_matching_plugins(t(), binary()) :: [module()]
  def get_matching_plugins(%__MODULE__{pattern_map: pattern_map, priority_sorted_plugins: sorted}, content) do
    # Fast pattern matching using pre-compiled map
    matching_plugins =
      pattern_map
      |> Enum.reduce([], fn {pattern, plugins}, acc ->
        if content_matches_pattern?(content, pattern) do
          plugins ++ acc
        else
          acc
        end
      end)
      |> Enum.uniq()

    # Return in priority order (already sorted)
    Enum.filter(sorted, &(&1 in matching_plugins))
  end

  @doc """
  Get a plugin's initialized state.
  """
  @spec get_plugin_state(t(), module()) :: term()
  def get_plugin_state(%__MODULE__{plugin_states: states}, plugin) do
    Map.get(states, plugin, %{})
  end

  @doc """
  Update a plugin's state in the context.
  """
  @spec put_plugin_state(t(), module(), term()) :: t()
  def put_plugin_state(%__MODULE__{} = context, plugin, new_state) do
    %{context | plugin_states: Map.put(context.plugin_states, plugin, new_state)}
  end

  @doc """
  Check if the context contains a specific plugin.
  """
  @spec has_plugin?(t(), module()) :: boolean()
  def has_plugin?(%__MODULE__{plugins: plugins}, plugin) do
    plugin in plugins
  end

  # Build a map from patterns to the plugins that use them
  defp build_pattern_map(plugins) do
    plugins
    |> Enum.flat_map(fn plugin ->
      patterns = plugin.patterns()
      Enum.map(patterns, fn pattern -> {pattern, plugin} end)
    end)
    |> Enum.group_by(fn {pattern, _plugin} -> pattern end, fn {_pattern, plugin} -> plugin end)
  end

  # Fast pattern matching - optimized for common cases
  defp content_matches_pattern?(content, pattern) when is_binary(pattern) do
    String.starts_with?(content, pattern)
  end

  defp content_matches_pattern?(content, %Regex{} = pattern) do
    Regex.match?(pattern, content)
  end

  defp content_matches_pattern?(_content, _pattern), do: false
end
