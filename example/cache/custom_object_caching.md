# Custom Object Caching Example

This example shows how to implement your own caching layer for parsing org content from database records or other structured objects with timestamps.

## Basic Database Record Caching

```elixir
defmodule MyApp.OrgContentCache do
  @moduledoc """
  Example caching layer for database records containing org content.
  
  Assumes your database records have fields like:
  - id: unique identifier
  - content: org-mode text
  - updated_at: timestamp for cache invalidation
  """
  
  use GenServer
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end
  
  def parse_records_cached(pid, records) do
    GenServer.call(pid, {:parse_records, records})
  end
  
  def clear_cache(pid) do
    GenServer.call(pid, :clear_cache)
  end
  
  # Server Implementation
  
  def init(_) do
    {:ok, %{cache: %{}, stats: %{hits: 0, misses: 0}}}
  end
  
  def handle_call({:parse_records, records}, _from, state) do
    {workspace, updated_state} = parse_with_cache(records, state)
    {:reply, {:ok, workspace}, updated_state}
  end
  
  def handle_call(:clear_cache, _from, state) do
    new_state = %{state | cache: %{}}
    {:reply, :ok, new_state}
  end
  
  # Private Functions
  
  defp parse_with_cache(records, state) do
    {cached_entries, cache_misses, updated_cache, stats} = 
      Enum.reduce(records, {[], [], state.cache, state.stats}, fn record, {entries, misses, cache, stats} ->
        cache_key = {record.id, record.updated_at}
        
        case Map.get(cache, cache_key) do
          nil ->
            # Cache miss
            {entries, [record | misses], cache, %{stats | misses: stats.misses + 1}}
          
          cached_entry ->
            # Cache hit - reuse immutable data structure
            {[cached_entry | entries], misses, cache, %{stats | hits: stats.hits + 1}}
        end
      end)
    
    # Parse cache misses
    case parse_new_records(cache_misses) do
      {:ok, new_entries} ->
        # Update cache with new entries
        final_cache = cache_misses
        |> Enum.zip(new_entries)
        |> Enum.reduce(updated_cache, fn {record, entry}, acc_cache ->
          cache_key = {record.id, record.updated_at}
          Map.put(acc_cache, cache_key, entry)
        end)
        
        all_entries = cached_entries ++ new_entries
        workspace = build_workspace_from_entries(all_entries)
        
        final_state = %{cache: final_cache, stats: stats}
        {workspace, final_state}
      
      {:error, reason} ->
        {{:error, reason}, %{cache: updated_cache, stats: stats}}
    end
  end
  
  defp parse_new_records(records) do
    # Convert records to format expected by batch parser
    content_list = Enum.map(records, fn record ->
      %{
        name: record.filename || "record_#{record.id}.org",
        content: record.content
      }
    end)
    
    case Org.BatchParser.parse_content(content_list) do
      {:ok, workspace} -> {:ok, workspace.file_entries}
      error -> error
    end
  end
  
  defp build_workspace_from_entries(entries) do
    %Org.BatchParser.Workspace{
      root_path: nil,
      file_entries: entries,
      index: build_index(entries),
      options: [],
      created_at: DateTime.utc_now()
    }
  end
  
  defp build_index(entries) do
    %{
      by_filename: Map.new(entries, &{&1.filename, &1}),
      by_tag: build_tag_index(entries)
    }
  end
  
  defp build_tag_index(entries) do
    entries
    |> Enum.flat_map(fn entry ->
      entry.tags |> Enum.map(&{&1, entry})
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end
end
```

## Usage Examples

```elixir
# Start the cache server
{:ok, cache_pid} = MyApp.OrgContentCache.start_link()

# Your database records (example structure)
records = [
  %{
    id: 1, 
    content: "* TODO Task 1\nThis is task 1", 
    updated_at: ~N[2024-01-01 10:00:00],
    filename: "task1.org"
  },
  %{
    id: 2, 
    content: "* DONE Task 2\nCompleted task", 
    updated_at: ~N[2024-01-01 11:00:00],
    filename: "task2.org"
  }
]

# First parse - all cache misses
{:ok, workspace} = MyApp.OrgContentCache.parse_records_cached(cache_pid, records)

# Second parse with same records - all cache hits (fast!)
{:ok, workspace2} = MyApp.OrgContentCache.parse_records_cached(cache_pid, records)

# Update one record in database, parse again - mixed hits/misses
updated_records = [
  %{records |> hd() | content: "* TODO Updated Task 1", updated_at: ~N[2024-01-01 12:00:00]},
  records |> Enum.at(1)  # unchanged
]

{:ok, workspace3} = MyApp.OrgContentCache.parse_records_cached(cache_pid, updated_records)
```

## Simple In-Memory Caching (No GenServer)

For simpler use cases, you can implement basic memoization:

```elixir
defmodule MyApp.SimpleOrgCache do
  @moduledoc """
  Simple stateless caching using Agent for storage.
  """
  
  def start_link do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end
  
  def parse_with_timestamps(content_items_with_timestamps) do
    cached_results = content_items_with_timestamps
    |> Enum.map(fn {content, timestamp, name} ->
      cache_key = :crypto.hash(:sha256, "#{name}:#{timestamp}:#{content}") |> Base.encode16()
      
      case Agent.get(__MODULE__, &Map.get(&1, cache_key)) do
        nil ->
          # Parse and cache
          {:ok, workspace} = Org.BatchParser.parse_content([%{name: name, content: content}])
          entry = hd(workspace.file_entries)
          Agent.update(__MODULE__, &Map.put(&1, cache_key, entry))
          {:miss, entry}
        
        cached_entry ->
          {:hit, cached_entry}
      end
    end)
    
    entries = Enum.map(cached_results, fn {_type, entry} -> entry end)
    
    # Build final workspace
    workspace = %Org.BatchParser.Workspace{
      root_path: nil,
      file_entries: entries,
      index: build_simple_index(entries),
      options: [],
      created_at: DateTime.utc_now()
    }
    
    {:ok, workspace}
  end
  
  defp build_simple_index(entries) do
    %{
      by_filename: Map.new(entries, &{&1.filename, &1}),
      by_tag: %{}
    }
  end
end

# Usage:
MyApp.SimpleOrgCache.start_link()

content_with_timestamps = [
  {"* TODO Database task", ~N[2024-01-01 10:00:00], "db_task.org"},
  {"* TODO API task", ~N[2024-01-01 11:00:00], "api_task.org"}
]

{:ok, workspace} = MyApp.SimpleOrgCache.parse_with_timestamps(content_with_timestamps)
```

## Key Benefits of This Approach

1. **You control the caching strategy** - Use timestamps, content hashes, or any other invalidation logic
2. **Leverages Elixir's immutability** - Cached entries are shared without copying
3. **Works with your data model** - Adapt to your database schema and business logic
4. **Optional complexity** - Use GenServer for advanced features, Agent for simple cases
5. **Clean separation** - Batch parser focuses on parsing, your code handles caching

## When to Use This Pattern

- ✅ Parsing org content from database records repeatedly
- ✅ Content that changes infrequently (documentation, templates, etc.)
- ✅ You have reliable timestamp/version fields for cache invalidation
- ✅ You want to optimize repeated parsing operations

## Alternative Approaches

- **ETS tables** for very high-performance caching
- **External cache systems** (Redis, Memcached) for distributed scenarios  
- **Database views/triggers** to pre-parse and cache results
- **Content-based hashing** if timestamps aren't available