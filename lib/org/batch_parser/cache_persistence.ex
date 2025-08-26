defmodule Org.BatchParser.CachePersistence do
  @moduledoc """
  Utilities for persisting batch parser cache to disk using Erlang's binary term format.

  Supports optional compression for efficient storage.
  """

  alias Org.BatchParser.Cache

  @doc """
  Save cache to a file using Erlang's binary term format.

  ## Examples

      cache = Org.BatchParser.Cache.new()
      # ... populate cache ...
      
      :ok = Org.BatchParser.CachePersistence.save(cache, "/tmp/org_cache.bin")
      {:ok, loaded_cache} = Org.BatchParser.CachePersistence.load("/tmp/org_cache.bin")
  """
  @spec save(Cache.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def save(cache, file_path, opts \\ []) do
    compress = Keyword.get(opts, :compress, true)

    try do
      external_term = Cache.to_external_term(cache)

      binary =
        if compress do
          :erlang.term_to_binary(external_term, [:compressed])
        else
          :erlang.term_to_binary(external_term)
        end

      # Create directory if it doesn't exist
      file_path |> Path.dirname() |> File.mkdir_p!()

      File.write!(file_path, binary)
      :ok
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Load cache from a file.
  """
  @spec load(String.t()) :: {:ok, Cache.t()} | {:error, term()}
  def load(file_path) do
    with {:ok, binary} <- File.read(file_path),
         external_term <- :erlang.binary_to_term(binary) do
      Cache.from_external_term(external_term)
    end
  rescue
    error -> {:error, error}
  end

  @doc """
  Get default cache file path for a directory.
  """
  @spec default_cache_path(String.t()) :: String.t()
  def default_cache_path(org_directory) do
    # Use XDG cache directory or fall back to tmp
    cache_dir =
      case System.get_env("XDG_CACHE_HOME") do
        nil -> Path.join([System.tmp_dir(), ".cache", "org_batch_parser"])
        path -> Path.join([path, "org_batch_parser"])
      end

    safe_name =
      org_directory
      |> String.replace(~r/[^a-zA-Z0-9_-]/, "_")
      # Limit length
      |> String.slice(0..100)

    Path.join(cache_dir, "#{safe_name}_cache.bin")
  end

  @doc """
  Auto-save cache with default settings.
  """
  @spec auto_save(Cache.t(), String.t()) :: :ok | {:error, term()}
  def auto_save(cache, org_directory) do
    cache_path = default_cache_path(org_directory)
    save(cache, cache_path)
  end

  @doc """
  Auto-load cache with default settings.
  """
  @spec auto_load(String.t()) :: {:ok, Cache.t()} | {:error, term()}
  def auto_load(org_directory) do
    cache_path = default_cache_path(org_directory)

    case File.exists?(cache_path) do
      true -> load(cache_path)
      false -> {:ok, Cache.new()}
    end
  end
end
