defmodule Org.Parser.Matcher do
  @moduledoc """
  High-performance pattern matching for parser plugins.

  Provides fast binary pattern matching and content routing
  to appropriate plugins with minimal overhead.
  """

  alias Org.Parser.Context

  @doc """
  Match content against registered plugins and execute the first matching one.

  Returns:
  - `{:handled, result}` - Plugin handled the content
  - `{:skip, remaining}` - Plugin skipped, try next
  - `:no_match` - No plugin matched
  """
  @spec match_and_parse(binary(), map(), [module()] | Context.t()) ::
          {:handled, term()} | {:skip, binary()} | :no_match
  def match_and_parse(content, context, plugins_or_context \\ [])

  # Handle context - fast path with pre-compiled patterns
  def match_and_parse(content, context, %Context{} = plugin_context) do
    plugins = Context.get_matching_plugins(plugin_context, content)

    # Try each plugin in priority order (already sorted by Context)
    Enum.reduce_while(plugins, :no_match, fn plugin, _acc ->
      enriched_context = Map.put(context, :plugin_state, Context.get_plugin_state(plugin_context, plugin))

      case try_plugin(plugin, content, enriched_context) do
        {:ok, result} ->
          {:halt, {:handled, result}}

        :skip ->
          {:cont, :no_match}

        {:skip, _reason} ->
          {:cont, :no_match}

        {:error, _reason} ->
          # Log error and continue
          {:cont, :no_match}
      end
    end)
  end

  # Handle direct plugin list (legacy/fallback approach)
  def match_and_parse(content, context, plugins) when is_list(plugins) do
    # Get potential plugins if not provided, or sort provided plugins
    plugins =
      if plugins == [] do
        Org.Parser.Registry.get_plugins_for(content)
      else
        # Sort provided plugins by priority
        Enum.sort_by(plugins, fn plugin -> plugin.priority() end)
      end

    # Try each plugin in priority order
    Enum.reduce_while(plugins, :no_match, fn plugin, _acc ->
      case try_plugin(plugin, content, context) do
        {:ok, result} ->
          {:halt, {:handled, result}}

        :skip ->
          {:cont, :no_match}

        {:skip, _reason} ->
          {:cont, :no_match}

        {:error, _reason} ->
          # Log error and continue
          {:cont, :no_match}
      end
    end)
  end

  @doc """
  Fast binary pattern matching for common org-mode structures.
  Returns the structure type for routing to appropriate handler.
  """
  @spec identify_content_type(binary()) :: atom()
  def identify_content_type(<<"#+BEGIN_SRC", _::binary>>), do: :code_block
  def identify_content_type(<<"#+begin_src", _::binary>>), do: :code_block
  def identify_content_type(<<"#+END_SRC", _::binary>>), do: :code_block_end
  def identify_content_type(<<"#+end_src", _::binary>>), do: :code_block_end
  def identify_content_type(<<"#+BEGIN:", _::binary>>), do: :dynamic_block
  def identify_content_type(<<"#+END:", _::binary>>), do: :dynamic_block_end
  def identify_content_type(<<"#+BEGIN_", _::binary>>), do: :block
  def identify_content_type(<<"#+END_", _::binary>>), do: :block_end
  def identify_content_type(<<"#", _::binary>>), do: :comment
  def identify_content_type(<<"*", _::binary>>), do: :section
  def identify_content_type(<<"|", _::binary>>), do: :table
  def identify_content_type(<<digit, ". ", _::binary>>) when digit in ?0..?9, do: :list
  def identify_content_type(<<digit, ") ", _::binary>>) when digit in ?0..?9, do: :list
  def identify_content_type(<<"[[", _::binary>>), do: :link
  def identify_content_type(<<":PROPERTIES:", _::binary>>), do: :property_drawer
  def identify_content_type(<<":END:", _::binary>>), do: :drawer_end

  def identify_content_type(content) when is_binary(content) do
    trimmed = String.trim_leading(content)
    identify_trimmed_content_type(trimmed)
  end

  defp identify_trimmed_content_type(trimmed) do
    cond do
      property_drawer?(trimmed) -> :property_drawer
      drawer_end?(trimmed) -> :drawer_end
      metadata?(trimmed) -> :metadata
      indented_list?(trimmed) -> :list
      true -> :paragraph
    end
  end

  defp property_drawer?(trimmed), do: String.starts_with?(trimmed, ":PROPERTIES:")
  defp drawer_end?(trimmed), do: String.starts_with?(trimmed, ":END:")

  defp metadata?(trimmed) do
    String.starts_with?(trimmed, "SCHEDULED:") or
      String.starts_with?(trimmed, "DEADLINE:") or
      String.starts_with?(trimmed, "CLOSED:")
  end

  defp indented_list?(trimmed) do
    Regex.match?(~r/^[-+]\s+/, trimmed) or
      Regex.match?(~r/^\*\s+/, trimmed) or
      Regex.match?(~r/^\d+[.)]\s+/, trimmed)
  end

  @doc """
  Fast extraction of block content between BEGIN and END markers.
  """
  @spec extract_block_content(binary(), binary()) :: {:ok, binary(), binary()} | :error
  def extract_block_content(content, block_type) do
    end_marker = "#+END_" <> block_type

    case :binary.split(content, end_marker, [:global]) do
      [block_content, rest] ->
        # Trim the block content
        trimmed = String.trim(block_content)
        {:ok, trimmed, rest}

      _ ->
        :error
    end
  end

  @doc """
  Extract parameters from a meta line like "#+BEGIN: name :param value"
  """
  @spec extract_meta_params(binary()) :: {binary(), keyword()}
  def extract_meta_params(line) do
    case String.split(line, " ", parts: 2) do
      [name] ->
        {name, []}

      [name, params_string] ->
        {name, parse_params(params_string)}
    end
  end

  # Private functions

  defp try_plugin(plugin, content, context) do
    plugin.parse(content, context)
  rescue
    error ->
      {:error, {plugin, error}}
  end

  defp parse_params(params_string) do
    params_string
    |> String.split(~r/\s+/)
    |> parse_param_pairs([])
  end

  defp parse_param_pairs([], acc), do: Enum.reverse(acc)

  defp parse_param_pairs([":" <> key | rest], acc) do
    {value, remaining} = take_param_value(rest)
    parse_param_pairs(remaining, [{String.to_atom(key), value} | acc])
  end

  defp parse_param_pairs([_skip | rest], acc) do
    parse_param_pairs(rest, acc)
  end

  defp take_param_value([]), do: {nil, []}
  defp take_param_value([":" <> _ | _] = rest), do: {nil, rest}

  defp take_param_value([value | rest]) do
    case take_param_value(rest) do
      {nil, remaining} -> {value, remaining}
      {more, remaining} -> {value <> " " <> more, remaining}
    end
  end
end
