defmodule Org.Plugins.DynamicBlock do
  @moduledoc """
  Plugin for parsing and handling dynamic blocks.

  Dynamic blocks are org-mode blocks that can be updated programmatically.
  They start with #+BEGIN: and end with #+END:

  Example:
      #+BEGIN: clocktable :scope file
      Dynamic content here
      #+END:
  """

  use Org.Parser.Plugin

  defmodule DynamicBlock do
    @moduledoc """
    Represents a dynamic block that can be updated.
    """
    defstruct [
      :name,
      :params,
      :content,
      :generator,
      :metadata
    ]

    @type t :: %__MODULE__{
            name: String.t(),
            params: keyword(),
            content: [String.t()],
            generator: (keyword() -> [String.t()]) | nil,
            metadata: map()
          }
  end

  @impl true
  def patterns do
    ["#+BEGIN:", "#+begin:"]
  end

  @impl true
  # Higher priority than static blocks
  def priority, do: 40

  @impl true
  def parse(<<"#+BEGIN:", rest::binary>>, context) do
    parse_dynamic_block(rest, context, "END:")
  end

  def parse(<<"#+begin:", rest::binary>>, context) do
    parse_dynamic_block(rest, context, "end:")
  end

  def parse(_, _), do: :skip

  @doc """
  Register a generator function for a dynamic block type.
  """
  @spec register_generator(String.t(), (keyword() -> [String.t()])) :: :ok
  def register_generator(block_name, generator_fun) do
    # Store in ETS or Registry
    :ets.insert(:dynamic_block_generators, {block_name, generator_fun})
    :ok
  end

  @doc """
  Update the content of a dynamic block using its generator.
  """
  @spec update_block(DynamicBlock.t()) :: DynamicBlock.t()
  def update_block(%DynamicBlock{generator: nil} = block), do: block

  def update_block(%DynamicBlock{generator: gen, params: params} = block) do
    new_content = gen.(params)
    %{block | content: new_content}
  end

  # Private functions

  defp parse_dynamic_block(content, _context, end_marker) do
    # Parse the header line to get block name and parameters
    {name, params, remaining} = parse_block_header(content)

    # Find the end marker
    end_pattern = "#+#{end_marker}"

    case extract_block_content(remaining, end_pattern) do
      {:ok, content_lines, _rest} ->
        # Look up generator function if registered
        generator = lookup_generator(name)

        block = %DynamicBlock{
          name: name,
          params: params,
          content: content_lines,
          generator: generator,
          metadata: %{
            created_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          }
        }

        {:ok, block}

      :error ->
        {:error, {:unclosed_dynamic_block, name}}
    end
  end

  defp parse_block_header(content) do
    case String.split(content, "\n", parts: 2) do
      [header, rest] ->
        {name, params} = parse_header_parts(header)
        {name, params, rest}

      [header] ->
        {name, params} = parse_header_parts(header)
        {name, params, ""}
    end
  end

  defp parse_header_parts(line) do
    trimmed = String.trim(line)

    case String.split(trimmed, " ", parts: 2) do
      [name, params_string] ->
        params = parse_params(params_string)
        {name, params}

      [name] ->
        {name, []}
    end
  end

  defp parse_params(params_string) do
    params_string
    |> String.split(~r/\s+/)
    |> parse_param_pairs([])
  end

  defp parse_param_pairs([], acc), do: Enum.reverse(acc)

  defp parse_param_pairs([":" <> key | rest], acc) do
    {value, remaining} = take_param_value(rest)
    key_atom = String.to_atom(key)
    parse_param_pairs(remaining, [{key_atom, value} | acc])
  end

  defp parse_param_pairs([value | rest], acc) when acc == [] do
    # First non-keyword parameter
    parse_param_pairs(rest, [{:default, value} | acc])
  end

  defp parse_param_pairs([_skip | rest], acc) do
    parse_param_pairs(rest, acc)
  end

  # Flag parameter
  defp take_param_value([]), do: {true, []}
  # Next param
  defp take_param_value([":" <> _ | _] = rest), do: {true, rest}

  defp take_param_value([value | rest]) do
    if String.starts_with?(value, ":") do
      {true, [value | rest]}
    else
      {values, remaining} = take_non_param_values(rest, [value])
      {Enum.join(values, " "), remaining}
    end
  end

  defp take_non_param_values([], acc), do: {Enum.reverse(acc), []}
  defp take_non_param_values([":" <> _ | _] = rest, acc), do: {Enum.reverse(acc), rest}

  defp take_non_param_values([value | rest], acc) do
    take_non_param_values(rest, [value | acc])
  end

  defp extract_block_content(content, end_marker) do
    lines = String.split(content, "\n")

    case find_end_marker(lines, end_marker, []) do
      {:found, content_lines, remaining} ->
        {:ok, Enum.reverse(content_lines), remaining}

      :not_found ->
        :error
    end
  end

  defp find_end_marker([], _marker, _acc), do: :not_found

  defp find_end_marker([line | rest], marker, acc) do
    if String.starts_with?(line, marker) do
      {:found, acc, rest}
    else
      find_end_marker(rest, marker, [line | acc])
    end
  end

  defp lookup_generator(name) do
    case :ets.lookup(:dynamic_block_generators, name) do
      [{^name, generator}] -> generator
      [] -> nil
    end
  catch
    :error, :badarg ->
      # Table doesn't exist yet
      nil
  end
end
