defmodule Org.BatchParser.DependencyGraph do
  @moduledoc """
  Builds and analyzes dependency graphs from internal links between org files.

  A dependency graph represents relationships between org files based on
  internal links. This can help identify:
  - File dependencies
  - Circular references
  - Orphaned files
  - Link clusters
  """

  defstruct [
    :nodes,
    :edges,
    :adjacency_list,
    :reverse_adjacency_list
  ]

  @type t :: %__MODULE__{
          nodes: MapSet.t(String.t()),
          edges: [edge()],
          adjacency_list: %{String.t() => [String.t()]},
          reverse_adjacency_list: %{String.t() => [String.t()]}
        }

  @type edge :: {String.t(), String.t()}

  alias Org.BatchParser.FileEntry

  @doc """
  Build a dependency graph from file entries.
  """
  @spec build([FileEntry.t()]) :: t()
  def build(file_entries) do
    nodes = build_nodes(file_entries)
    edges = build_edges(file_entries)
    adjacency_list = build_adjacency_list(edges)
    reverse_adjacency_list = build_reverse_adjacency_list(edges)

    %__MODULE__{
      nodes: nodes,
      edges: edges,
      adjacency_list: adjacency_list,
      reverse_adjacency_list: reverse_adjacency_list
    }
  end

  @doc """
  Get all files that link to the specified file.
  """
  @spec incoming_links(t(), String.t()) :: [String.t()]
  def incoming_links(%__MODULE__{reverse_adjacency_list: reverse_adj}, filename) do
    Map.get(reverse_adj, filename, [])
  end

  @doc """
  Get all files that the specified file links to.
  """
  @spec outgoing_links(t(), String.t()) :: [String.t()]
  def outgoing_links(%__MODULE__{adjacency_list: adj}, filename) do
    Map.get(adj, filename, [])
  end

  @doc """
  Find all cycles in the dependency graph.
  """
  @spec find_cycles(t()) :: [[String.t()]]
  def find_cycles(%__MODULE__{} = graph) do
    visited = MapSet.new()
    rec_stack = MapSet.new()
    cycles = []

    graph.nodes
    |> Enum.reduce({cycles, visited}, fn node, {acc_cycles, acc_visited} ->
      if MapSet.member?(acc_visited, node) do
        {acc_cycles, acc_visited}
      else
        find_cycles_dfs(graph, node, acc_visited, rec_stack, acc_cycles, [])
      end
    end)
    |> elem(0)
  end

  @doc """
  Find strongly connected components (clusters of mutually linked files).
  """
  @spec strongly_connected_components(t()) :: [[String.t()]]
  def strongly_connected_components(%__MODULE__{} = graph) do
    # Tarjan's algorithm for finding SCCs
    state = %{
      index: 0,
      stack: [],
      indices: %{},
      lowlinks: %{},
      on_stack: MapSet.new(),
      components: []
    }

    graph.nodes
    |> Enum.reduce(state, fn node, acc_state ->
      if Map.has_key?(acc_state.indices, node) do
        acc_state
      else
        tarjan_strongconnect(graph, node, acc_state)
      end
    end)
    |> Map.get(:components)
  end

  @doc """
  Find orphaned files (files with no incoming or outgoing links).
  """
  @spec orphaned_files(t()) :: [String.t()]
  def orphaned_files(%__MODULE__{} = graph) do
    graph.nodes
    |> Enum.filter(fn node ->
      incoming = length(incoming_links(graph, node))
      outgoing = length(outgoing_links(graph, node))
      incoming == 0 and outgoing == 0
    end)
    |> Enum.to_list()
  end

  @doc """
  Get graph statistics.
  """
  @spec stats(t()) :: map()
  def stats(%__MODULE__{} = graph) do
    %{
      node_count: MapSet.size(graph.nodes),
      edge_count: length(graph.edges),
      cycles: length(find_cycles(graph)),
      orphaned_files: length(orphaned_files(graph)),
      strongly_connected_components: length(strongly_connected_components(graph))
    }
  end

  @doc """
  Export graph to DOT format for visualization.
  """
  @spec to_dot(t()) :: String.t()
  def to_dot(%__MODULE__{} = graph) do
    nodes_dot = Enum.map_join(graph.nodes, "\n", fn node -> "  \"#{node}\";" end)

    edges_dot = Enum.map_join(graph.edges, "\n", fn {from, to} -> "  \"#{from}\" -> \"#{to}\";" end)

    """
    digraph dependencies {
      rankdir=LR;
      node [shape=box, style=rounded];
      
    #{nodes_dot}

    #{edges_dot}
    }
    """
  end

  # Private functions

  defp build_nodes(file_entries) do
    file_entries
    |> Enum.map(& &1.filename)
    |> MapSet.new()
  end

  defp build_edges(file_entries) do
    file_entries
    |> Enum.flat_map(fn entry ->
      entry.links
      |> Enum.map(&extract_filename_from_link/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn target -> {entry.filename, target} end)
    end)
  end

  defp extract_filename_from_link(%{url: url}) do
    cond do
      # File link: file:path/to/file.org
      String.starts_with?(url, "file:") ->
        url
        |> String.replace_prefix("file:", "")
        |> Path.basename()

      # Simple file reference: path/to/file.org
      String.ends_with?(url, ".org") ->
        Path.basename(url)

      # Internal link to same file: #section or *heading
      String.starts_with?(url, "#") or String.starts_with?(url, "*") ->
        nil

      # External links (http, https, etc.)
      true ->
        nil
    end
  end

  defp build_adjacency_list(edges) do
    edges
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  defp build_reverse_adjacency_list(edges) do
    edges
    |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))
  end

  defp find_cycles_dfs(graph, node, visited, rec_stack, cycles, current_path) do
    new_visited = MapSet.put(visited, node)
    new_rec_stack = MapSet.put(rec_stack, node)
    new_path = [node | current_path]

    neighbors = outgoing_links(graph, node)

    {final_cycles, final_visited} =
      Enum.reduce(neighbors, {cycles, new_visited}, fn neighbor, {acc_cycles, acc_visited} ->
        cond do
          MapSet.member?(new_rec_stack, neighbor) ->
            # Found a cycle
            cycle_start_index = Enum.find_index(new_path, &(&1 == neighbor))
            cycle = Enum.take(new_path, cycle_start_index + 1) |> Enum.reverse()
            {[cycle | acc_cycles], acc_visited}

          not MapSet.member?(acc_visited, neighbor) ->
            find_cycles_dfs(graph, neighbor, acc_visited, new_rec_stack, acc_cycles, new_path)

          true ->
            {acc_cycles, acc_visited}
        end
      end)

    {final_cycles, final_visited}
  end

  defp tarjan_strongconnect(graph, node, state) do
    # Set the depth index for this node
    new_state = %{
      state
      | indices: Map.put(state.indices, node, state.index),
        lowlinks: Map.put(state.lowlinks, node, state.index),
        index: state.index + 1,
        stack: [node | state.stack],
        on_stack: MapSet.put(state.on_stack, node)
    }

    # Consider successors of node
    neighbors = outgoing_links(graph, node)

    final_state =
      Enum.reduce(neighbors, new_state, fn neighbor, acc_state ->
        cond do
          not Map.has_key?(acc_state.indices, neighbor) ->
            # Successor has not yet been visited; recurse on it
            updated_state = tarjan_strongconnect(graph, neighbor, acc_state)
            neighbor_lowlink = Map.get(updated_state.lowlinks, neighbor)
            current_lowlink = Map.get(updated_state.lowlinks, node)

            %{updated_state | lowlinks: Map.put(updated_state.lowlinks, node, min(current_lowlink, neighbor_lowlink))}

          MapSet.member?(acc_state.on_stack, neighbor) ->
            # Successor is in stack and hence in the current SCC
            neighbor_index = Map.get(acc_state.indices, neighbor)
            current_lowlink = Map.get(acc_state.lowlinks, node)

            %{acc_state | lowlinks: Map.put(acc_state.lowlinks, node, min(current_lowlink, neighbor_index))}

          true ->
            acc_state
        end
      end)

    # If node is a root node, pop the stack and create an SCC
    node_lowlink = Map.get(final_state.lowlinks, node)
    node_index = Map.get(final_state.indices, node)

    if node_lowlink == node_index do
      {component, remaining_stack, remaining_on_stack} =
        pop_component(final_state.stack, final_state.on_stack, node, [])

      %{
        final_state
        | stack: remaining_stack,
          on_stack: remaining_on_stack,
          components: [component | final_state.components]
      }
    else
      final_state
    end
  end

  defp pop_component([head | tail], on_stack, target, component) do
    new_component = [head | component]
    new_on_stack = MapSet.delete(on_stack, head)

    if head == target do
      {new_component, tail, new_on_stack}
    else
      pop_component(tail, new_on_stack, target, new_component)
    end
  end
end
