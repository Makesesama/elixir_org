defmodule Org.BatchParser.Workspace do
  @moduledoc """
  Represents a parsed workspace containing multiple org files.

  A workspace aggregates all parsed org files and provides indexes
  for efficient querying and data access.
  """

  defstruct [
    :root_path,
    :file_entries,
    :index,
    :options,
    :created_at
  ]

  @type t :: %__MODULE__{
          root_path: String.t() | nil,
          file_entries: [Org.BatchParser.FileEntry.t()],
          index: map(),
          options: keyword(),
          created_at: DateTime.t()
        }

  @doc """
  Create a new empty workspace.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      root_path: nil,
      file_entries: [],
      index: %{},
      options: [],
      created_at: DateTime.utc_now()
    }
  end

  @doc """
  Get all files in the workspace.
  """
  @spec files(t()) :: [Org.BatchParser.FileEntry.t()]
  def files(%__MODULE__{file_entries: entries}), do: entries

  @doc """
  Get a file by its filename.
  """
  @spec get_file(t(), String.t()) :: Org.BatchParser.FileEntry.t() | nil
  def get_file(%__MODULE__{index: index}, filename) do
    Map.get(index[:by_filename] || %{}, filename)
  end

  @doc """
  Get all files containing a specific tag.
  """
  @spec files_with_tag(t(), String.t()) :: [Org.BatchParser.FileEntry.t()]
  def files_with_tag(%__MODULE__{index: index}, tag) do
    Map.get(index[:by_tag] || %{}, tag, [])
  end

  @doc """
  Get statistics about the workspace.
  """
  @spec stats(t()) :: map()
  def stats(%__MODULE__{} = workspace) do
    %{
      file_count: length(workspace.file_entries),
      tag_count: count_unique_tags(workspace),
      created_at: workspace.created_at
    }
  end

  defp count_unique_tags(workspace) do
    workspace.file_entries
    |> Enum.flat_map(& &1.tags)
    |> Enum.uniq()
    |> length()
  end
end
