defmodule Org.BatchParser do
  @moduledoc """
  Batch parser for processing multiple org-mode files.

  This module provides functionality to:
  - Parse multiple org files in parallel
  - Provide structured document data for external processing
  - Build dependency graphs from internal links
  - Index parsed results for performance

  ## Example Usage

      # Parse all org files in a directory
      {:ok, workspace} = Org.BatchParser.parse_directory("/path/to/org/files")
      
      # Access parsed documents for external processing
      documents = Enum.map(workspace.file_entries, & &1.document)
      
      # Get dependency graph
      graph = Org.BatchParser.dependency_graph(workspace)
      
      # External libraries can traverse documents as needed
      files_with_todos = Enum.filter(workspace.file_entries, fn entry ->
        has_todo_sections?(entry.document)
      end)
  """

  alias Org.BatchParser.{Cache, DependencyGraph, FileEntry, Workspace}

  @type parse_options :: [
          recursive: boolean(),
          extensions: [String.t()],
          parallel: boolean(),
          cache: boolean(),
          include_archived: boolean()
        ]

  @default_options [
    recursive: true,
    extensions: [".org"],
    parallel: true,
    cache: true,
    include_archived: false
  ]

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Parse all org files in a directory.

  ## Options

  - `:recursive` - Recursively search subdirectories (default: true)
  - `:extensions` - File extensions to include (default: [".org"])
  - `:parallel` - Parse files in parallel (default: true)
  - `:cache` - Cache parsed results (default: true)
  - `:include_archived` - Include archived items (default: false)

  ## Examples

      {:ok, workspace} = Org.BatchParser.parse_directory("~/org")
      
      {:ok, workspace} = Org.BatchParser.parse_directory("~/org", 
        recursive: false,
        extensions: [".org", ".txt"]
      )
  """
  @spec parse_directory(String.t(), parse_options()) :: {:ok, Workspace.t()} | {:error, term()}
  def parse_directory(path, opts \\ []) do
    opts = Keyword.merge(@default_options, opts)

    with {:ok, files} <- collect_files(path, opts),
         {:ok, entries} <- parse_file_list(files, opts) do
      workspace = build_workspace(entries, path, opts)
      {:ok, workspace}
    end
  end

  @doc """
  Parse specific org files.

  ## Examples

      {:ok, workspace} = Org.BatchParser.parse_files([
        "/path/to/file1.org",
        "/path/to/file2.org"
      ])
  """
  @spec parse_files([String.t()], parse_options()) :: {:ok, Workspace.t()} | {:error, term()}
  def parse_files(file_paths, opts \\ []) do
    opts = Keyword.merge(@default_options, opts)

    with {:ok, entries} <- parse_file_list(file_paths, opts) do
      workspace = build_workspace(entries, nil, opts)
      {:ok, workspace}
    end
  end

  @doc """
  Parse org content from strings or content objects.

  Accepts a list of content items where each item can be:
  - A string containing org content
  - A map with `:content` and optional `:name` keys
  - A tuple `{name, content}` where name is used as the file identifier

  ## Examples

      # Parse from strings (names will be generated)
      {:ok, workspace} = Org.BatchParser.parse_content([
        "* TODO Task 1\\nThis is content",
        "* DONE Task 2\\nCompleted task"
      ])
      
      # Parse from maps with names
      {:ok, workspace} = Org.BatchParser.parse_content([
        %{name: "project.org", content: "* TODO Project task"},
        %{name: "notes.org", content: "* Some notes"}
      ])
      
      # Parse from tuples
      {:ok, workspace} = Org.BatchParser.parse_content([
        {"ideas.org", "* TODO New idea\\nExplore this"},
        {"tasks.org", "* TODO [#A] Important task"}
      ])
  """
  @spec parse_content([String.t() | map() | {String.t(), String.t()}], parse_options()) ::
          {:ok, Workspace.t()} | {:error, term()}
  def parse_content(content_list, opts \\ []) do
    opts = Keyword.merge(@default_options, opts)

    with {:ok, entries} <- parse_content_list(content_list, opts) do
      workspace = build_workspace(entries, nil, opts)
      {:ok, workspace}
    end
  end

  @doc """
  Parse org documents from already parsed Org.Document structs.

  Accepts a list of documents or document-name pairs.

  ## Examples

      doc1 = Org.load_string("* TODO Task")
      doc2 = Org.load_string("* DONE Completed")
      
      # Parse from documents (names will be generated)
      {:ok, workspace} = Org.BatchParser.parse_documents([doc1, doc2])
      
      # Parse from document-name pairs
      {:ok, workspace} = Org.BatchParser.parse_documents([
        {"project.org", doc1},
        {"completed.org", doc2}
      ])
      
      ## Caching Examples
      
      # Parse with caching enabled
      cache = Org.BatchParser.Cache.new()
      {:ok, workspace, updated_cache} = Org.BatchParser.parse_directory_cached("~/org", cache)
      
      # Second parse reuses cached entries
      {:ok, workspace2, final_cache} = Org.BatchParser.parse_directory_cached("~/org", updated_cache)
  """
  @spec parse_documents([Org.Document.t() | {String.t(), Org.Document.t()}], parse_options()) ::
          {:ok, Workspace.t()} | {:error, term()}
  def parse_documents(documents, opts \\ []) do
    opts = Keyword.merge(@default_options, opts)

    entries = build_entries_from_documents(documents)
    workspace = build_workspace(entries, nil, opts)
    {:ok, workspace}
  end

  @doc """
  Parse all org files in a directory with caching support.

  Returns both the workspace and an updated cache. Unchanged files are
  reused from the cache, while changed files are re-parsed.

  ## Examples

      cache = Org.BatchParser.Cache.new()
      {:ok, workspace, updated_cache} = Org.BatchParser.parse_directory_cached(
        "~/org", 
        cache,
        recursive: true
      )
      
      # Later, reuse the cache for faster parsing
      {:ok, workspace2, final_cache} = Org.BatchParser.parse_directory_cached(
        "~/org",
        updated_cache
      )
  """
  @spec parse_directory_cached(String.t(), Cache.t(), parse_options()) ::
          {:ok, Workspace.t(), Cache.t()} | {:error, term()}
  def parse_directory_cached(path, cache, opts \\ []) do
    opts = Keyword.merge(@default_options, opts)

    with {:ok, files} <- collect_files(path, opts),
         {:ok, entries, updated_cache} <- parse_file_list_cached(files, cache, opts) do
      workspace = build_workspace(entries, path, opts)
      {:ok, workspace, updated_cache}
    end
  end

  @doc """
  Parse specific org files with caching support.

  ## Examples

      cache = Org.BatchParser.Cache.new()
      {:ok, workspace, updated_cache} = Org.BatchParser.parse_files_cached([
        "/path/to/file1.org",
        "/path/to/file2.org"
      ], cache)
  """
  @spec parse_files_cached([String.t()], Cache.t(), parse_options()) ::
          {:ok, Workspace.t(), Cache.t()} | {:error, term()}
  def parse_files_cached(file_paths, cache, opts \\ []) do
    opts = Keyword.merge(@default_options, opts)

    with {:ok, entries, updated_cache} <- parse_file_list_cached(file_paths, cache, opts) do
      workspace = build_workspace(entries, nil, opts)
      {:ok, workspace, updated_cache}
    end
  end

  @doc """
  Build a dependency graph from internal links between files.

  Returns a directed graph where nodes are files and edges represent links.

  ## Examples

      graph = Org.BatchParser.dependency_graph(workspace)
      
      # Get files that link to a specific file
      incoming = DependencyGraph.incoming_links(graph, "project.org")
      
      # Get files that a specific file links to
      outgoing = DependencyGraph.outgoing_links(graph, "project.org")
      
      # Find cycles in dependencies
      cycles = DependencyGraph.find_cycles(graph)
  """
  @spec dependency_graph(Workspace.t()) :: DependencyGraph.t()
  def dependency_graph(%Workspace{} = workspace) do
    DependencyGraph.build(workspace.file_entries)
  end

  # ============================================================================
  # Private Functions - File Collection
  # ============================================================================

  defp parse_file_list(file_paths, opts) do
    if opts[:parallel] do
      parse_files_parallel(file_paths)
    else
      parse_files_sequential(file_paths)
    end
  end

  defp parse_file_list_cached(file_paths, cache, opts) do
    if opts[:parallel] do
      parse_files_parallel_cached(file_paths, cache)
    else
      parse_files_sequential_cached(file_paths, cache)
    end
  end

  defp parse_content_list(content_list, opts) do
    if opts[:parallel] do
      parse_content_parallel(content_list)
    else
      parse_content_sequential(content_list)
    end
  end

  defp build_entries_from_documents(documents) do
    documents
    |> Enum.with_index()
    |> Enum.map(fn {doc_or_tuple, index} ->
      case doc_or_tuple do
        {name, %Org.Document{} = doc} ->
          build_file_entry_from_document(name, doc)

        %Org.Document{} = doc ->
          name = "document_#{index + 1}.org"
          build_file_entry_from_document(name, doc)
      end
    end)
  end

  defp collect_files(path, opts) do
    extensions = opts[:extensions]

    if opts[:recursive] do
      collect_files_recursive(path, extensions)
    else
      collect_files_flat(path, extensions)
    end
  end

  defp collect_files_recursive(path, extensions) do
    case File.ls(path) do
      {:ok, entries} ->
        files =
          entries
          |> Enum.map(&Path.join(path, &1))
          |> Enum.flat_map(&collect_single_entry(&1, extensions))

        {:ok, files}

      error ->
        error
    end
  end

  defp collect_single_entry(entry, extensions) do
    cond do
      File.dir?(entry) ->
        case collect_files_recursive(entry, extensions) do
          {:ok, files} -> files
          {:error, _} -> []
        end

      has_valid_extension?(entry, extensions) ->
        [entry]

      true ->
        []
    end
  end

  defp collect_files_flat(path, extensions) do
    case File.ls(path) do
      {:ok, entries} ->
        files =
          entries
          |> Enum.map(&Path.join(path, &1))
          |> Enum.filter(&(File.regular?(&1) and has_valid_extension?(&1, extensions)))

        {:ok, files}

      error ->
        error
    end
  end

  defp has_valid_extension?(path, extensions) do
    Enum.any?(extensions, &String.ends_with?(path, &1))
  end

  # ============================================================================
  # Private Functions - Content Parsing
  # ============================================================================

  defp parse_content_parallel(content_list) do
    tasks =
      Enum.with_index(content_list)
      |> Enum.map(fn {content_item, index} ->
        Task.async(fn -> parse_single_content(content_item, index) end)
      end)

    results = Task.await_many(tasks, 30_000)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      entries = Enum.map(results, fn {:ok, entry} -> entry end)
      {:ok, entries}
    else
      {:error, {:parse_errors, errors}}
    end
  end

  defp parse_content_sequential(content_list) do
    results =
      content_list
      |> Enum.with_index()
      |> Enum.map(fn {content_item, index} -> parse_single_content(content_item, index) end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      entries = Enum.map(results, fn {:ok, entry} -> entry end)
      {:ok, entries}
    else
      {:error, {:parse_errors, errors}}
    end
  end

  defp parse_single_content(content_item, index) do
    {name, content} = extract_name_and_content(content_item, index)
    doc = Org.load_string(content)
    entry = build_file_entry_from_document(name, doc)
    {:ok, entry}
  rescue
    error -> {:error, {content_item, error}}
  catch
    :throw, error -> {:error, {content_item, error}}
  end

  defp extract_name_and_content(content_item, index) do
    case content_item do
      content when is_binary(content) ->
        {"content_#{index + 1}.org", content}

      %{name: name, content: content} ->
        {name, content}

      %{content: content} ->
        {"content_#{index + 1}.org", content}

      {name, content} when is_binary(name) and is_binary(content) ->
        {name, content}

      _ ->
        throw({:invalid_content_format, content_item})
    end
  end

  # ============================================================================
  # Private Functions - Cached File Parsing
  # ============================================================================

  defp parse_files_sequential_cached(file_paths, cache) do
    {entries, updated_cache, errors} =
      Enum.reduce(file_paths, {[], cache, []}, fn path, {acc_entries, acc_cache, acc_errors} ->
        case parse_single_file_cached(path, acc_cache) do
          {:ok, entry, new_cache} ->
            {[entry | acc_entries], new_cache, acc_errors}

          {:error, error} ->
            {acc_entries, acc_cache, [error | acc_errors]}
        end
      end)

    if Enum.empty?(errors) do
      {:ok, Enum.reverse(entries), updated_cache}
    else
      {:error, {:parse_errors, Enum.reverse(errors)}}
    end
  end

  defp parse_files_parallel_cached(file_paths, cache) do
    # For parallel caching, we need to be careful about cache state
    # First, check cache for all files and separate hits from misses
    {cache_hits, cache_misses, updated_cache} =
      Enum.reduce(file_paths, {[], [], cache}, fn path, {hits, misses, acc_cache} ->
        case Cache.get(acc_cache, path) do
          {:hit, entry, new_cache} ->
            {[entry | hits], misses, new_cache}

          {:miss, new_cache} ->
            {hits, [path | misses], new_cache}
        end
      end)

    # Parse cache misses in parallel
    case parse_files_parallel(cache_misses) do
      {:ok, new_entries} ->
        # Store new entries in cache
        final_cache =
          Enum.zip(cache_misses, new_entries)
          |> Enum.reduce(updated_cache, fn {path, entry}, acc_cache ->
            Cache.put(acc_cache, path, entry)
          end)

        all_entries = cache_hits ++ new_entries
        {:ok, all_entries, final_cache}

      error ->
        error
    end
  end

  defp parse_single_file_cached(path, cache) do
    case Cache.get(cache, path) do
      {:hit, entry, updated_cache} ->
        {:ok, entry, updated_cache}

      {:miss, updated_cache} ->
        case parse_single_file(path) do
          {:ok, entry} ->
            final_cache = Cache.put(updated_cache, path, entry)
            {:ok, entry, final_cache}

          error ->
            error
        end
    end
  end

  # ============================================================================
  # Private Functions - File Parsing
  # ============================================================================

  defp parse_files_parallel(file_paths) do
    tasks =
      Enum.map(file_paths, fn path ->
        Task.async(fn -> parse_single_file(path) end)
      end)

    results = Task.await_many(tasks, 30_000)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      entries = Enum.map(results, fn {:ok, entry} -> entry end)
      {:ok, entries}
    else
      {:error, {:parse_errors, errors}}
    end
  end

  defp parse_files_sequential(file_paths) do
    results = Enum.map(file_paths, &parse_single_file/1)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      entries = Enum.map(results, fn {:ok, entry} -> entry end)
      {:ok, entries}
    else
      {:error, {:parse_errors, errors}}
    end
  end

  defp parse_single_file(path) do
    with {:ok, content} <- File.read(path),
         doc <- Org.load_string(content) do
      entry = build_file_entry(path, doc)
      {:ok, entry}
    else
      error -> {:error, {path, error}}
    end
  end

  defp build_file_entry(path, doc) do
    %FileEntry{
      path: path,
      filename: Path.basename(path),
      document: doc,
      file_properties: doc.file_properties,
      links: extract_links(doc),
      tags: extract_all_tags(doc),
      modified_at: get_file_mtime(path)
    }
  end

  defp build_file_entry_from_document(name, doc) do
    %FileEntry{
      path: name,
      filename: name,
      document: doc,
      file_properties: doc.file_properties,
      links: extract_links(doc),
      tags: extract_all_tags(doc),
      # No file modification time for in-memory content
      modified_at: nil
    }
  end

  # ============================================================================
  # Private Functions - Data Extraction
  # ============================================================================

  defp extract_links(doc) do
    doc
    |> extract_all_content()
    |> Enum.flat_map(&extract_links_from_content/1)
  end

  defp extract_all_content(doc) do
    section_contents =
      doc.sections
      |> Enum.flat_map(&extract_section_content/1)

    doc.contents ++ section_contents
  end

  defp extract_section_content(section) do
    child_contents =
      section.children
      |> Enum.flat_map(&extract_section_content/1)

    section.contents ++ child_contents
  end

  defp extract_links_from_content(%Org.Paragraph{lines: lines}) do
    lines
    |> Enum.flat_map(&extract_links_from_line/1)
  end

  defp extract_links_from_content(_), do: []

  defp extract_links_from_line(line) when is_binary(line) do
    # Extract links from plain text line using regex
    regex = ~r/\[\[([^\]]+)\](?:\[([^\]]+)\])?\]/

    Regex.scan(regex, line)
    |> Enum.map(fn
      [_, url] -> %{url: url, description: nil}
      [_, url, desc] -> %{url: url, description: desc}
    end)
  end

  defp extract_links_from_line(%Org.FormattedText{spans: spans}) do
    spans
    |> Enum.filter(&match?(%Org.FormattedText.Link{}, &1))
    |> Enum.map(fn %Org.FormattedText.Link{url: url, description: desc} ->
      %{url: url, description: desc}
    end)
  end

  defp extract_links_from_line(_), do: []

  defp extract_all_tags(doc) do
    file_tags = parse_filetags(doc.file_properties["FILETAGS"] || "")

    section_tags =
      doc.sections
      |> Enum.flat_map(&extract_section_tags/1)

    (file_tags ++ section_tags)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp extract_section_tags(section) do
    child_tags =
      section.children
      |> Enum.flat_map(&extract_section_tags/1)

    (section.tags || []) ++ child_tags
  end

  defp parse_filetags(filetags_string) when is_binary(filetags_string) do
    filetags_string
    |> String.trim()
    |> String.trim_leading(":")
    |> String.trim_trailing(":")
    |> case do
      "" -> []
      trimmed -> String.split(trimmed, ":")
    end
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_filetags(_), do: []

  # ============================================================================
  # Private Functions - Workspace Building
  # ============================================================================

  defp build_workspace(entries, root_path, opts) do
    %Workspace{
      root_path: root_path,
      file_entries: entries,
      index: build_index(entries),
      options: opts,
      created_at: DateTime.utc_now()
    }
  end

  defp build_index(entries) do
    %{
      by_filename: build_filename_index(entries),
      by_tag: build_tag_index(entries)
    }
  end

  defp build_filename_index(entries) do
    Map.new(entries, &{&1.filename, &1})
  end

  defp build_tag_index(entries) do
    entries
    |> Enum.flat_map(fn entry ->
      entry.tags
      |> Enum.map(&{&1, entry})
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  # ============================================================================
  # Private Functions - Misc
  # ============================================================================

  defp get_file_mtime(path) do
    case File.stat(path) do
      {:ok, %{mtime: mtime}} -> mtime
      _ -> nil
    end
  end
end
