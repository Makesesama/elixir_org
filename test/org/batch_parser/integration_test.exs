defmodule Org.BatchParser.IntegrationTest do
  use ExUnit.Case

  alias Org.BatchParser
  alias Org.BatchParser.{Cache, CachePersistence}

  describe "caching integration" do
    test "cached parsing reuses unchanged files" do
      # Create a temporary directory for testing
      test_dir = System.tmp_dir!() |> Path.join("org_cache_integration_#{System.unique_integer()}")
      File.mkdir_p!(test_dir)

      # Create test org files
      file1_content = """
      #+TITLE: Project Overview
      #+AUTHOR: John Doe
      #+FILETAGS: :project:management:

      * TODO [#A] Complete project setup
      This is an important task.
      """

      file2_content = """
      #+TITLE: Technical Specifications
      #+AUTHOR: Jane Smith

      * TODO Database design
      This needs to be done.
      """

      file1_path = Path.join(test_dir, "overview.org")
      file2_path = Path.join(test_dir, "specs.org")
      File.write!(file1_path, file1_content)
      File.write!(file2_path, file2_content)

      # First parse with empty cache
      cache = Cache.new()
      {:ok, workspace1, updated_cache} = BatchParser.parse_directory_cached(test_dir, cache)

      # Verify results
      assert length(workspace1.file_entries) == 2
      assert Cache.size(updated_cache) == 2
      # No hits on first parse
      assert Cache.hit_ratio(updated_cache) == 0.0

      # Second parse should reuse cached entries
      {:ok, workspace2, final_cache} = BatchParser.parse_directory_cached(test_dir, updated_cache)

      # Results should be the same
      assert length(workspace2.file_entries) == 2
      assert Cache.size(final_cache) == 2
      # Should have cache hits now
      assert Cache.hit_ratio(final_cache) > 0.0

      # Modify one file
      # Ensure mtime changes
      :timer.sleep(1010)
      File.write!(file1_path, file1_content <> "\n* DONE Additional task\n")

      # Third parse should reuse one cached file, re-parse the modified one
      {:ok, workspace3, third_cache} = BatchParser.parse_directory_cached(test_dir, final_cache)

      assert length(workspace3.file_entries) == 2
      assert Cache.size(third_cache) == 2

      # Cache should show mixed hits/misses
      stats = Cache.stats(third_cache)
      assert stats.cache_hits > 0
      assert stats.cache_misses > 0

      # Clean up
      File.rm_rf!(test_dir)
    end

    test "cache persistence roundtrip" do
      test_dir = System.tmp_dir!() |> Path.join("org_persistence_#{System.unique_integer()}")
      File.mkdir_p!(test_dir)

      # Create test file
      File.write!(Path.join(test_dir, "test.org"), "* TODO Test task")

      # Parse with caching
      cache = Cache.new()
      {:ok, workspace, updated_cache} = BatchParser.parse_directory_cached(test_dir, cache)

      assert length(workspace.file_entries) == 1
      assert Cache.size(updated_cache) == 1

      # Save cache to disk
      cache_file = Path.join(System.tmp_dir(), "test_cache_#{System.unique_integer()}.bin")
      :ok = CachePersistence.save(updated_cache, cache_file)

      # Load cache from disk
      {:ok, loaded_cache} = CachePersistence.load(cache_file)

      # Verify loaded cache works
      {:ok, workspace2, final_cache} = BatchParser.parse_directory_cached(test_dir, loaded_cache)

      assert length(workspace2.file_entries) == 1
      # Should have cache hit
      assert Cache.hit_ratio(final_cache) > 0.0

      # Clean up
      File.rm_rf!(test_dir)
      File.rm!(cache_file)
    end
  end
end
