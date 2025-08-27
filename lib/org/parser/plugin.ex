defmodule Org.Parser.Plugin do
  @moduledoc """
  Behaviour for high-performance parser plugins.

  Plugins can extend the parser by:
  - Adding custom block types
  - Handling new token types
  - Transforming parsed content
  - Overriding default parsing behavior

  ## Performance Considerations

  Plugins are designed for maximum performance:
  - Pattern matching happens at compile time when possible
  - Fast binary pattern matching is preferred
  - Plugins can provide `fast_match?/1` for quick pre-filtering
  - Priority system ensures efficient ordering

  ## Example

      defmodule MyCustomBlockPlugin do
        use Org.Parser.Plugin
        
        @impl true
        def patterns do
          ["#+BEGIN: my_block", ~r/^#\\+BEGIN: custom_/]
        end
        
        @impl true
        def priority, do: 50  # Higher priority than default (100)
        
        @impl true
        def parse(<<"#+BEGIN: my_block", rest::binary>>, context) do
          # Fast binary pattern matching
          case parse_my_block(rest) do
            {:ok, content} -> {:ok, %MyBlock{content: content}}
            error -> error
          end
        end
      end
  """

  @type parse_result ::
          {:ok, term()}
          # Continue with modified input
          | {:cont, binary(), term()}
          # Skip this content, continue parsing
          | {:skip, binary()}
          | {:error, term()}

  @type context :: %{
          optional(:section_stack) => [Org.Section.t()],
          optional(:parent) => term(),
          optional(:metadata) => map(),
          optional(atom()) => term()
        }

  @doc """
  Return patterns this plugin can handle.
  Can be strings (for exact prefix match) or regexes.
  """
  @callback patterns() :: [binary() | Regex.t()]

  @doc """
  Return priority (lower number = higher priority).
  Default is 100. Use < 100 to override defaults.
  """
  @callback priority() :: integer()

  @doc """
  Parse the matched content.
  """
  @callback parse(binary(), context()) :: parse_result()

  @doc """
  Optional: Quick check if content might match.
  Used for fast pre-filtering before full pattern matching.
  """
  @callback fast_match?(binary()) :: boolean()

  @doc """
  Optional: Transform already parsed content.
  Called after successful parsing for post-processing.
  """
  @callback transform(term(), context()) :: term()

  @doc """
  Optional: Initialize plugin state.
  Called once when plugin is loaded.
  """
  @callback init(keyword()) :: {:ok, term()} | {:error, term()}

  @optional_callbacks [fast_match?: 1, transform: 2, init: 1]

  defmacro __using__(_opts) do
    quote do
      @behaviour Org.Parser.Plugin

      # Default implementations
      def priority, do: 100
      def fast_match?(_), do: true
      def transform(content, _context), do: content
      def init(_opts), do: {:ok, nil}

      defoverridable priority: 0, fast_match?: 1, transform: 2, init: 1
    end
  end
end
