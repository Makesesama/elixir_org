defmodule Org.BatchParser.CacheTest do
  use ExUnit.Case

  alias Org.BatchParser.{Cache, FileEntry}

  describe "cache basic functionality" do
    test "creates empty cache" do
      cache = Cache.new()

      assert Cache.empty?(cache)
      assert Cache.size(cache) == 0
      assert Cache.hit_ratio(cache) == 0.0
    end

    test "cache miss for non-existent file" do
      cache = Cache.new()

      {:miss, updated_cache} = Cache.get(cache, "/nonexistent/file.org")

      assert Cache.size(updated_cache) == 0
      stats = Cache.stats(updated_cache)
      assert stats.cache_misses == 1
      assert stats.cache_hits == 0
    end

    test "cache put and get cycle" do
      # Create a temporary file for testing
      temp_file = Path.join(System.tmp_dir(), "cache_test_#{System.unique_integer()}.org")
      File.write!(temp_file, "* Test content")

      # Create a mock file entry
      doc = Org.load_string("* Test content")

      file_entry = %FileEntry{
        path: temp_file,
        filename: Path.basename(temp_file),
        document: doc,
        file_properties: %{},
        links: [],
        tags: [],
        modified_at: nil
      }

      cache = Cache.new()

      # Put entry in cache
      updated_cache = Cache.put(cache, temp_file, file_entry)

      assert Cache.size(updated_cache) == 1
      refute Cache.empty?(updated_cache)

      # Get entry from cache
      {:hit, cached_entry, final_cache} = Cache.get(updated_cache, temp_file)

      assert cached_entry == file_entry
      stats = Cache.stats(final_cache)
      assert stats.cache_hits == 1
      assert Cache.hit_ratio(final_cache) == 1.0

      # Clean up
      File.rm!(temp_file)
    end

    test "cache invalidation when file changes" do
      # Create a temporary file
      temp_file = Path.join(System.tmp_dir(), "cache_invalidation_test_#{System.unique_integer()}.org")
      File.write!(temp_file, "* Original content")

      doc1 = Org.load_string("* Original content")

      file_entry1 = %FileEntry{
        path: temp_file,
        filename: Path.basename(temp_file),
        document: doc1,
        file_properties: %{},
        links: [],
        tags: [],
        modified_at: nil
      }

      cache = Cache.new()

      # Cache the original file
      cache_with_entry = Cache.put(cache, temp_file, file_entry1)

      # Verify cache hit
      {:hit, cached_entry, _} = Cache.get(cache_with_entry, temp_file)
      assert cached_entry == file_entry1

      # Modify the file (ensure different mtime)
      # Ensure mtime changes
      :timer.sleep(1010)
      File.write!(temp_file, "* Modified content")

      # Should be cache miss now due to changed mtime
      {:miss, updated_cache} = Cache.get(cache_with_entry, temp_file)

      stats = Cache.stats(updated_cache)
      assert stats.cache_misses == 1

      # Clean up
      File.rm!(temp_file)
    end

    test "cache cleanup removes stale entries" do
      # Create temporary files
      temp_file1 = Path.join(System.tmp_dir(), "cleanup_test1_#{System.unique_integer()}.org")
      temp_file2 = Path.join(System.tmp_dir(), "cleanup_test2_#{System.unique_integer()}.org")

      File.write!(temp_file1, "* Test 1")
      File.write!(temp_file2, "* Test 2")

      doc = Org.load_string("* Test content")

      entry1 = %FileEntry{
        path: temp_file1,
        filename: "test1.org",
        document: doc,
        file_properties: %{},
        links: [],
        tags: [],
        modified_at: nil
      }

      entry2 = %FileEntry{
        path: temp_file2,
        filename: "test2.org",
        document: doc,
        file_properties: %{},
        links: [],
        tags: [],
        modified_at: nil
      }

      cache =
        Cache.new()
        |> Cache.put(temp_file1, entry1)
        |> Cache.put(temp_file2, entry2)

      assert Cache.size(cache) == 2

      # Delete one file
      File.rm!(temp_file2)

      # Cleanup should remove the stale entry
      cleaned_cache = Cache.cleanup_stale_entries(cache)

      assert Cache.size(cleaned_cache) == 1

      # Verify the remaining entry is the right one
      {:hit, remaining_entry, _} = Cache.get(cleaned_cache, temp_file1)
      assert remaining_entry == entry1

      # Clean up remaining file
      File.rm!(temp_file1)
    end

    test "cache statistics and info" do
      cache = Cache.new()

      info = Cache.info(cache)
      assert info.size == 0
      assert info.hit_ratio == 0.0
      assert info.oldest_entry == nil
      assert info.newest_entry == nil
      assert info.files == []

      # Add some mock entries to test info
      temp_file = Path.join(System.tmp_dir(), "info_test_#{System.unique_integer()}.org")
      File.write!(temp_file, "* Test")

      doc = Org.load_string("* Test")

      entry = %FileEntry{
        path: temp_file,
        filename: "test.org",
        document: doc,
        file_properties: %{},
        links: [],
        tags: [],
        modified_at: nil
      }

      updated_cache = Cache.put(cache, temp_file, entry)

      info = Cache.info(updated_cache)
      assert info.size == 1
      assert length(info.files) == 1
      assert hd(info.files) == temp_file
      assert info.oldest_entry != nil
      assert info.newest_entry != nil

      # Clean up
      File.rm!(temp_file)
    end

    test "cache clear" do
      temp_file = Path.join(System.tmp_dir(), "clear_test_#{System.unique_integer()}.org")
      File.write!(temp_file, "* Test")

      doc = Org.load_string("* Test")

      entry = %FileEntry{
        path: temp_file,
        filename: "test.org",
        document: doc,
        file_properties: %{},
        links: [],
        tags: [],
        modified_at: nil
      }

      cache =
        Cache.new()
        |> Cache.put(temp_file, entry)

      assert Cache.size(cache) == 1

      cleared_cache = Cache.clear(cache)

      assert Cache.empty?(cleared_cache)
      assert Cache.size(cleared_cache) == 0

      # Clean up
      File.rm!(temp_file)
    end
  end

  describe "cache serialization" do
    test "external term serialization round trip" do
      temp_file = Path.join(System.tmp_dir(), "serialization_test_#{System.unique_integer()}.org")
      File.write!(temp_file, "* Test content")

      doc = Org.load_string("* Test content")

      entry = %FileEntry{
        path: temp_file,
        filename: "test.org",
        document: doc,
        file_properties: %{"TITLE" => "Test"},
        links: [],
        tags: ["test"],
        modified_at: nil
      }

      original_cache = Cache.new() |> Cache.put(temp_file, entry)

      # Serialize and deserialize
      external_term = Cache.to_external_term(original_cache)
      {:ok, restored_cache} = Cache.from_external_term(external_term)

      # Verify the cache was restored correctly
      assert Cache.size(restored_cache) == Cache.size(original_cache)

      {:hit, restored_entry, _} = Cache.get(restored_cache, temp_file)
      assert restored_entry.filename == entry.filename
      assert restored_entry.file_properties == entry.file_properties
      assert restored_entry.tags == entry.tags

      # Clean up
      File.rm!(temp_file)
    end
  end
end
