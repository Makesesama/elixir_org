defmodule Org.Parser.Registry do
  @moduledoc """
  High-performance plugin registry using ETS for fast lookups.

  Manages parser plugins with minimal overhead:
  - ETS table for O(1) lookups
  - Compiled pattern matching
  - Priority-based ordering
  - No runtime GenServer calls in hot path

  ## Usage

      # Register plugins at startup
      Org.Parser.Registry.start()
      Org.Parser.Registry.register_plugin(MyCustomPlugin, [])
      
      # Fast lookup during parsing
      plugins = Org.Parser.Registry.get_plugins_for("#+BEGIN: custom")
  """

  @table_name :org_parser_plugins
  @pattern_table :org_parser_patterns

  @type plugin_entry :: {
          module :: module(),
          priority :: integer(),
          patterns :: [binary() | Regex.t()],
          state :: term()
        }

  @doc """
  Start the registry (creates ETS tables).
  Should be called once at application startup.
  """
  def start do
    # Check if tables already exist
    case {:ets.whereis(@table_name), :ets.whereis(@pattern_table)} do
      {:undefined, :undefined} ->
        # Create tables with race condition protection
        try do
          :ets.new(@table_name, [
            :set,
            :public,
            :named_table,
            read_concurrency: true,
            write_concurrency: true
          ])
        rescue
          # Table already exists (race condition)
          ArgumentError -> :ok
        end

        try do
          :ets.new(@pattern_table, [
            # Multiple values per key
            :bag,
            :public,
            :named_table,
            read_concurrency: true,
            write_concurrency: true
          ])
        rescue
          # Table already exists (race condition)
          ArgumentError -> :ok
        end

        :ok

      _ ->
        # Tables exist, just return ok (don't clear during tests)
        :ok
    end
  end

  @doc """
  Register a plugin module.
  """
  @spec register_plugin(module(), keyword()) :: :ok | {:error, term()}
  def register_plugin(plugin_module, opts \\ []) do
    with :ok <- validate_plugin(plugin_module),
         {:ok, state} <- plugin_module.init(opts) do
      patterns = plugin_module.patterns()
      priority = plugin_module.priority()

      # Store plugin info
      entry = {plugin_module, priority, patterns, state}

      try do
        :ets.insert(@table_name, {plugin_module, entry})

        # Index patterns for fast lookup
        Enum.each(patterns, fn pattern ->
          key = pattern_key(pattern)
          :ets.insert(@pattern_table, {key, {plugin_module, priority}})
        end)
      rescue
        ArgumentError ->
          # ETS table doesn't exist, start it first
          start()
          :ets.insert(@table_name, {plugin_module, entry})

          Enum.each(patterns, fn pattern ->
            key = pattern_key(pattern)
            :ets.insert(@pattern_table, {key, {plugin_module, priority}})
          end)
      end

      :ok
    end
  end

  @doc """
  Get all plugins that might handle the given content.
  Returns plugins sorted by priority (ascending).
  """
  @spec get_plugins_for(binary()) :: [module()]
  def get_plugins_for(content) when is_binary(content) do
    # Get all registered plugins and filter by patterns
    list_plugins()
    |> filter_by_patterns(content)
    |> Enum.sort_by(fn plugin ->
      try do
        case :ets.lookup(@table_name, plugin) do
          [{^plugin, {_mod, priority, _patterns, _state}}] -> priority
          # fallback priority
          [] -> 999
        end
      rescue
        # Table doesn't exist, use fallback priority
        ArgumentError -> 999
      end
    end)
  end

  @doc """
  Get a specific plugin's state.
  """
  @spec get_plugin_state(module()) :: term() | nil
  def get_plugin_state(plugin_module) do
    case :ets.lookup(@table_name, plugin_module) do
      [{^plugin_module, {_mod, _priority, _patterns, state}}] -> state
      [] -> nil
    end
  end

  @doc """
  List all registered plugins.
  """
  @spec list_plugins() :: [module()]
  def list_plugins do
    :ets.tab2list(@table_name)
    |> Enum.map(fn {module, _} -> module end)
  rescue
    # Table doesn't exist
    ArgumentError -> []
  end

  @doc """
  Clear all registered plugins.
  """
  @spec clear() :: :ok
  def clear do
    try do
      if :ets.whereis(@table_name) != :undefined do
        :ets.delete_all_objects(@table_name)
      end

      if :ets.whereis(@pattern_table) != :undefined do
        :ets.delete_all_objects(@pattern_table)
      end
    rescue
      # Table doesn't exist
      ArgumentError -> :ok
    end

    :ok
  end

  # Private functions

  defp validate_plugin(module) do
    # Try calling the functions directly instead of using function_exported?
    # which seems to have issues with behaviours
    module.patterns()
    module.priority()
    # Don't test parse/2 as it might raise for invalid input
    :ok
  rescue
    _ ->
      {:error, {:invalid_plugin, module}}
  end

  # Extract key for fast pattern lookup
  defp pattern_key(pattern) when is_binary(pattern) do
    # Use the full pattern as key for fast lookup, normalized to lowercase
    String.downcase(pattern)
  end

  defp pattern_key(%Regex{} = regex) do
    # For regex, use a special key
    {:regex, Regex.source(regex)}
  end

  # Extract lookup key from content

  # Filter plugins by their actual patterns
  defp filter_by_patterns(plugins, content) do
    Enum.filter(plugins, fn plugin ->
      try do
        case :ets.lookup(@table_name, plugin) do
          [{^plugin, {_mod, _priority, patterns, _state}}] ->
            plugin_matches?(patterns, content, plugin)

          [] ->
            false
        end
      rescue
        # Table doesn't exist
        ArgumentError -> false
      end
    end)
  end

  defp plugin_matches?(patterns, content, plugin) do
    # First check fast_match if available
    if function_exported?(plugin, :fast_match?, 1) and not plugin.fast_match?(content) do
      false
    else
      # Check actual patterns
      Enum.any?(patterns, fn
        pattern when is_binary(pattern) ->
          String.starts_with?(content, pattern)

        %Regex{} = regex ->
          Regex.match?(regex, content)
      end)
    end
  end
end
