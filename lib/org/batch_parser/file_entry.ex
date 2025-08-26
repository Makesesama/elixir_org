defmodule Org.BatchParser.FileEntry do
  @moduledoc """
  Represents a single parsed org file within a workspace.

  Contains the parsed document and extracted metadata for efficient
  querying and indexing.
  """

  defstruct [
    :path,
    :filename,
    :document,
    :file_properties,
    :links,
    :tags,
    :modified_at
  ]

  @type t :: %__MODULE__{
          path: String.t(),
          filename: String.t(),
          document: Org.Document.t(),
          file_properties: %{String.t() => String.t()},
          links: [map()],
          tags: [String.t()],
          modified_at: term()
        }

  @doc """
  Create a new file entry from a path and parsed document.
  """
  @spec new(String.t(), Org.Document.t()) :: t()
  def new(path, %Org.Document{} = doc) do
    %__MODULE__{
      path: path,
      filename: Path.basename(path),
      document: doc,
      file_properties: doc.file_properties,
      links: [],
      tags: [],
      modified_at: get_file_mtime(path)
    }
  end

  @doc """
  Get the file's title from TITLE property or filename.
  """
  @spec title(t()) :: String.t()
  def title(%__MODULE__{file_properties: props, filename: filename}) do
    Map.get(props, "TITLE", Path.rootname(filename))
  end

  @doc """
  Get the file's author from AUTHOR property.
  """
  @spec author(t()) :: String.t() | nil
  def author(%__MODULE__{file_properties: props}) do
    Map.get(props, "AUTHOR")
  end

  @doc """
  Check if the file has been modified since the entry was created.
  """
  @spec modified?(t()) :: boolean()
  def modified?(%__MODULE__{path: path, modified_at: original_mtime}) do
    case get_file_mtime(path) do
      ^original_mtime -> false
      _ -> true
    end
  end

  @doc """
  Get all sections from the document.
  """
  @spec sections(t()) :: [Org.Section.t()]
  def sections(%__MODULE__{document: doc}) do
    doc.sections
  end

  @doc """
  Get all paragraphs from the document.
  """
  @spec paragraphs(t()) :: [Org.Paragraph.t()]
  def paragraphs(%__MODULE__{document: doc}) do
    Org.paragraphs(doc)
  end

  @doc """
  Get all lists from the document.
  """
  @spec lists(t()) :: [Org.List.t()]
  def lists(%__MODULE__{document: doc}) do
    Org.lists(doc)
  end

  @doc """
  Get all tables from the document.
  """
  @spec tables(t()) :: [Org.Table.t()]
  def tables(%__MODULE__{document: doc}) do
    Org.tables(doc)
  end

  @doc """
  Get all code blocks from the document.
  """
  @spec code_blocks(t()) :: [Org.CodeBlock.t()]
  def code_blocks(%__MODULE__{document: doc}) do
    Org.code_blocks(doc)
  end

  @doc """
  Convert to a JSON-serializable map.
  """
  @spec to_json_map(t()) :: map()
  def to_json_map(%__MODULE__{} = entry) do
    %{
      path: entry.path,
      filename: entry.filename,
      title: title(entry),
      author: author(entry),
      file_properties: entry.file_properties,
      link_count: length(entry.links),
      tags: entry.tags,
      modified_at: entry.modified_at
    }
  end

  defp get_file_mtime(path) do
    case File.stat(path) do
      {:ok, %{mtime: mtime}} -> mtime
      _ -> nil
    end
  end
end
