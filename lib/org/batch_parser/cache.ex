defmodule Org.BatchParser.Cache do
  @moduledoc """
  Caching system for batch parser that leverages Elixir's immutable data structures.

  The cache stores parsed file entries keyed by file path and modification time,
  allowing efficient reuse of unchanged files while detecting when files need
  to be re-parsed.

  ## Features

  - File-level caching based on modification time
  - Immutable data sharing (no copying overhead)
  - Cache invalidation on file changes
  - Optional persistence to disk
  - Memory-efficient incremental updates

  ## Example Usage

      # Create a new cache
      cache = Org.BatchParser.Cache.new()
      
      # Parse with caching enabled
      {:ok, workspace, updated_cache} = Org.BatchParser.parse_directory_cached(
        "/path/to/org", 
        cache
      )
      
      # Second parse reuses cached entries for unchanged files
      {:ok, workspace2, final_cache} = Org.BatchParser.parse_directory_cached(
        "/path/to/org",
        updated_cache  
      )
  """

  defstruct [
    :entries,
    :stats,
    :created_at,
    :last_updated_at
  ]

  # {file_path, modification_time}
  @type cache_key :: {String.t(), term()}

  @type cache_entry :: %{
          file_entry: Org.BatchParser.FileEntry.t(),
          cached_at: DateTime.t(),
          file_size: integer(),
          checksum: String.t() | nil
        }

  @type cache_stats :: %{
          total_entries: integer(),
          cache_hits: integer(),
          cache_misses: integer(),
          last_cleanup: DateTime.t() | nil
        }

  @type t :: %__MODULE__{
          entries: %{cache_key() => cache_entry()},
          stats: cache_stats(),
          created_at: DateTime.t(),
          last_updated_at: DateTime.t()
        }

  @doc """
  Create a new empty cache.
  """
  @spec new() :: t()
  def new do
    now = DateTime.utc_now()

    %__MODULE__{
      entries: %{},
      stats: %{
        total_entries: 0,
        cache_hits: 0,
        cache_misses: 0,
        last_cleanup: nil
      },
      created_at: now,
      last_updated_at: now
    }
  end

  @doc """
  Get a cached file entry if it exists and is still valid.
  """
  @spec get(t(), String.t()) :: {:hit, Org.BatchParser.FileEntry.t(), t()} | {:miss, t()}
  def get(%__MODULE__{} = cache, file_path) do
    case File.stat(file_path) do
      {:ok, %{mtime: current_mtime, size: current_size}} ->
        cache_key = {file_path, current_mtime}

        case Map.get(cache.entries, cache_key) do
          %{file_entry: file_entry, file_size: cached_size} when cached_size == current_size ->
            updated_stats = %{cache.stats | cache_hits: cache.stats.cache_hits + 1}
            updated_cache = %{cache | stats: updated_stats}
            {:hit, file_entry, updated_cache}

          _ ->
            # Cache miss - file changed or not cached
            updated_stats = %{cache.stats | cache_misses: cache.stats.cache_misses + 1}
            updated_cache = %{cache | stats: updated_stats}
            {:miss, updated_cache}
        end

      {:error, _} ->
        # File doesn't exist or can't be accessed
        updated_stats = %{cache.stats | cache_misses: cache.stats.cache_misses + 1}
        updated_cache = %{cache | stats: updated_stats}
        {:miss, updated_cache}
    end
  end

  @doc """
  Store a parsed file entry in the cache.
  """
  @spec put(t(), String.t(), Org.BatchParser.FileEntry.t()) :: t()
  def put(%__MODULE__{} = cache, file_path, file_entry) do
    case File.stat(file_path) do
      {:ok, %{mtime: mtime, size: size}} ->
        cache_key = {file_path, mtime}

        cache_entry = %{
          file_entry: file_entry,
          cached_at: DateTime.utc_now(),
          file_size: size,
          # Could add checksum for extra validation
          checksum: nil
        }

        # Remove any old entries for this file path
        cleaned_entries = remove_old_entries_for_path(cache.entries, file_path)
        new_entries = Map.put(cleaned_entries, cache_key, cache_entry)

        updated_stats = %{cache.stats | total_entries: map_size(new_entries)}

        %{cache | entries: new_entries, stats: updated_stats, last_updated_at: DateTime.utc_now()}

      {:error, _} ->
        # Can't stat file, don't cache
        cache
    end
  end

  @doc """
  Remove entries for files that no longer exist.
  """
  @spec cleanup_stale_entries(t()) :: t()
  def cleanup_stale_entries(%__MODULE__{} = cache) do
    valid_entries =
      cache.entries
      |> Enum.filter(fn {{file_path, _mtime}, _entry} ->
        File.exists?(file_path)
      end)
      |> Map.new()

    updated_stats = %{cache.stats | total_entries: map_size(valid_entries), last_cleanup: DateTime.utc_now()}

    %{cache | entries: valid_entries, stats: updated_stats, last_updated_at: DateTime.utc_now()}
  end

  @doc """
  Remove all entries from the cache.
  """
  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = cache) do
    %{cache | entries: %{}, stats: %{cache.stats | total_entries: 0}, last_updated_at: DateTime.utc_now()}
  end

  @doc """
  Get cache statistics.
  """
  @spec stats(t()) :: cache_stats()
  def stats(%__MODULE__{stats: stats}), do: stats

  @doc """
  Calculate cache hit ratio.
  """
  @spec hit_ratio(t()) :: float()
  def hit_ratio(%__MODULE__{stats: %{cache_hits: hits, cache_misses: misses}}) do
    total = hits + misses
    if total > 0, do: hits / total, else: 0.0
  end

  @doc """
  Get the size of the cache in number of entries.
  """
  @spec size(t()) :: integer()
  def size(%__MODULE__{stats: %{total_entries: count}}), do: count

  @doc """
  Check if cache is empty.
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{stats: %{total_entries: 0}}), do: true
  def empty?(%__MODULE__{}), do: false

  @doc """
  Get information about cached files.
  """
  @spec info(t()) :: %{
          size: integer(),
          hit_ratio: float(),
          oldest_entry: DateTime.t() | nil,
          newest_entry: DateTime.t() | nil,
          files: [String.t()]
        }
  def info(%__MODULE__{} = cache) do
    cached_times =
      cache.entries
      |> Map.values()
      |> Enum.map(& &1.cached_at)

    files =
      cache.entries
      |> Map.keys()
      |> Enum.map(fn {path, _mtime} -> path end)
      |> Enum.uniq()

    %{
      size: size(cache),
      hit_ratio: hit_ratio(cache),
      oldest_entry: if(cached_times != [], do: Enum.min(cached_times), else: nil),
      newest_entry: if(cached_times != [], do: Enum.max(cached_times), else: nil),
      files: files
    }
  end

  @doc """
  Serialize cache to a term that can be stored to disk.
  """
  @spec to_external_term(t()) :: term()
  def to_external_term(%__MODULE__{} = cache) do
    %{
      entries: cache.entries,
      stats: cache.stats,
      created_at: cache.created_at,
      last_updated_at: cache.last_updated_at,
      version: 1
    }
  end

  @doc """
  Deserialize cache from external term.
  """
  @spec from_external_term(term()) :: {:ok, t()} | {:error, term()}
  def from_external_term(%{version: 1} = term) do
    cache = %__MODULE__{
      entries: term.entries,
      stats: term.stats,
      created_at: term.created_at,
      last_updated_at: term.last_updated_at
    }

    {:ok, cache}
  rescue
    error -> {:error, error}
  end

  def from_external_term(_), do: {:error, :unsupported_version}

  # Private functions

  defp remove_old_entries_for_path(entries, file_path) do
    entries
    |> Enum.reject(fn {{path, _mtime}, _entry} -> path == file_path end)
    |> Map.new()
  end
end
