defmodule Org.FileProperties do
  @moduledoc """
  Handles parsing and rendering of org-mode file-level properties.

  File-level properties are special lines that appear at the beginning of org files
  and provide metadata about the entire document. They follow the format #+KEY: value.

  ## Supported Properties

  Common file-level properties include:
  - #+TITLE: Document title
  - #+AUTHOR: Document author
  - #+EMAIL: Author email
  - #+DATE: Creation/modification date
  - #+FILETAGS: Tags that apply to the entire file
  - #+DESCRIPTION: Brief document description
  - #+KEYWORDS: Keywords for the document
  - #+LANGUAGE: Document language code
  - #+OPTIONS: Export options
  - #+STARTUP: Initial display options

  ## Format

  File properties must start with #+ followed by the property name, a colon, and the value:

      #+TITLE: My Document
      #+AUTHOR: John Doe
      #+FILETAGS: :project:important:
      #+DATE: 2024-01-15

  """

  @type file_properties :: %{String.t() => String.t()}

  @doc """
  Parses file-level properties from the beginning of org-mode content.

  File properties must appear at the very beginning of the document, before any content.
  Once a non-property line is encountered, property parsing stops.

  Returns a tuple of `{properties, remaining_lines}` where properties is a map
  of property names to values, and remaining_lines are the lines after properties.

  ## Examples

      iex> lines = ["#+TITLE: My Document", "#+AUTHOR: John Doe", "", "* First Section"]
      iex> Org.FileProperties.parse_properties(lines)
      {%{"TITLE" => "My Document", "AUTHOR" => "John Doe"}, ["", "* First Section"]}

      iex> lines = ["Regular content", "#+TITLE: Won't be parsed"]
      iex> Org.FileProperties.parse_properties(lines)
      {%{}, ["Regular content", "#+TITLE: Won't be parsed"]}
  """
  @spec parse_properties([String.t()]) :: {file_properties(), [String.t()]}
  def parse_properties(lines) do
    parse_property_lines(lines, %{})
  end

  defp parse_property_lines([line | rest], properties) do
    trimmed = String.trim(line)

    cond do
      String.starts_with?(trimmed, "#+") ->
        handle_property_line(trimmed, line, rest, properties)

      trimmed == "" ->
        handle_empty_line(line, rest, properties)

      true ->
        # Not a property line, stop parsing
        {properties, [line | rest]}
    end
  end

  defp parse_property_lines([], properties) do
    {properties, []}
  end

  defp handle_property_line(trimmed, line, rest, properties) do
    case parse_file_property_line(trimmed) do
      {key, value} ->
        parse_property_lines(rest, Map.put(properties, key, value))

      nil ->
        # Not a valid property, stop parsing
        {properties, [line | rest]}
    end
  end

  defp handle_empty_line(line, rest, properties) do
    case find_next_non_empty_line(rest) do
      {next_non_empty, _} ->
        handle_empty_line_with_next(line, rest, properties, next_non_empty)

      nil ->
        handle_empty_line_at_end(line, rest, properties)
    end
  end

  defp handle_empty_line_with_next(line, rest, properties, next_non_empty) do
    trimmed_next = String.trim(next_non_empty)

    is_next_property =
      String.starts_with?(trimmed_next, "#+") and
        parse_file_property_line(trimmed_next) != nil

    if is_next_property do
      # Next non-empty line is a property, consume this empty line
      parse_property_lines(rest, properties)
    else
      # Next non-empty line is not a property, stop parsing
      {properties, [line | rest]}
    end
  end

  defp handle_empty_line_at_end(line, rest, properties) do
    if properties == %{} do
      # If we haven't parsed any properties yet, consume all remaining empty lines
      parse_property_lines(rest, properties)
    else
      # If we have properties, don't consume trailing empty line
      {properties, [line | rest]}
    end
  end

  defp find_next_non_empty_line([]), do: nil

  defp find_next_non_empty_line([line | rest]) do
    if String.trim(line) == "" do
      find_next_non_empty_line(rest)
    else
      {line, rest}
    end
  end

  # Keywords that are directives/comments rather than file properties
  @excluded_keywords ~w[COMMENT BEGIN_SRC END_SRC BEGIN_EXAMPLE END_EXAMPLE BEGIN_QUOTE END_QUOTE BEGIN_CENTER END_CENTER]

  @doc """
  Parses a single file property line.

  Returns `{key, value}` tuple or `nil` if the line is not a valid file property.
  Excludes certain keywords that are directives rather than properties.

  ## Examples

      iex> Org.FileProperties.parse_file_property_line("#+TITLE: My Document")
      {"TITLE", "My Document"}

      iex> Org.FileProperties.parse_file_property_line("#+AUTHOR: John Doe")
      {"AUTHOR", "John Doe"}

      iex> Org.FileProperties.parse_file_property_line("#+FILETAGS: :tag1:tag2:")
      {"FILETAGS", ":tag1:tag2:"}

      iex> Org.FileProperties.parse_file_property_line("#+COMMENT: Not a property")
      nil

      iex> Org.FileProperties.parse_file_property_line("# Not a property")
      nil

      iex> Org.FileProperties.parse_file_property_line("#+INVALID")
      nil
  """
  @spec parse_file_property_line(String.t()) :: {String.t(), String.t()} | nil
  def parse_file_property_line(line) do
    case Regex.run(~r/^#\+([A-Z_][A-Z0-9_]*)\s*:\s*(.*)$/, String.trim(line)) do
      [_, key, value] ->
        if key in @excluded_keywords do
          nil
        else
          {String.trim(key), String.trim(value)}
        end

      nil ->
        nil
    end
  end

  @doc """
  Renders file properties back to org-mode format.

  Properties are sorted alphabetically by key for consistent output.

  ## Examples

      iex> props = %{"TITLE" => "My Document", "AUTHOR" => "John Doe"}
      iex> Org.FileProperties.render_properties(props)
      ["#+AUTHOR: John Doe", "#+TITLE: My Document"]

      iex> Org.FileProperties.render_properties(%{})
      []
  """
  @spec render_properties(file_properties()) :: [String.t()]
  def render_properties(properties) when properties == %{} do
    []
  end

  def render_properties(properties) do
    properties
    |> Enum.sort_by(fn {key, _} -> key end)
    |> Enum.map(fn {key, value} -> "#+#{key}: #{value}" end)
  end

  @doc """
  Checks if a line is a file property line.

  ## Examples

      iex> Org.FileProperties.file_property_line?("#+TITLE: My Document")
      true

      iex> Org.FileProperties.file_property_line?("  #+AUTHOR: John Doe  ")
      true

      iex> Org.FileProperties.file_property_line?("# Comment")
      false

      iex> Org.FileProperties.file_property_line?("Regular text")
      false
  """
  @spec file_property_line?(String.t()) :: boolean()
  def file_property_line?(line) do
    trimmed = String.trim(line)
    String.match?(trimmed, ~r/^#\+[A-Z_][A-Z0-9_]*\s*:/)
  end

  @doc """
  Extracts specific common properties into a structured format.

  This function recognizes common org-mode file properties and provides
  easier access to them with appropriate type conversion where applicable.

  ## Examples

      iex> props = %{"TITLE" => "My Doc", "FILETAGS" => ":tag1:tag2:", "DATE" => "2024-01-15"}
      iex> structured = Org.FileProperties.extract_structured_properties(props)
      iex> structured.title
      "My Doc"
      iex> structured.tags
      ["tag1", "tag2"]
  """
  @spec extract_structured_properties(file_properties()) :: %{
          title: String.t() | nil,
          author: String.t() | nil,
          email: String.t() | nil,
          date: String.t() | nil,
          tags: [String.t()],
          description: String.t() | nil,
          keywords: String.t() | nil,
          language: String.t() | nil,
          options: String.t() | nil,
          startup: String.t() | nil
        }
  def extract_structured_properties(properties) do
    %{
      title: Map.get(properties, "TITLE"),
      author: Map.get(properties, "AUTHOR"),
      email: Map.get(properties, "EMAIL"),
      date: Map.get(properties, "DATE"),
      tags: parse_filetags(Map.get(properties, "FILETAGS", "")),
      description: Map.get(properties, "DESCRIPTION"),
      keywords: Map.get(properties, "KEYWORDS"),
      language: Map.get(properties, "LANGUAGE"),
      options: Map.get(properties, "OPTIONS"),
      startup: Map.get(properties, "STARTUP")
    }
  end

  # Parse FILETAGS from :tag1:tag2: format
  defp parse_filetags(""), do: []

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
    |> Enum.map(&String.trim/1)
  end

  defp parse_filetags(_), do: []
end
