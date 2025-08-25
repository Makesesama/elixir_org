defmodule Org.PropertyDrawer do
  @moduledoc """
  Handles parsing and rendering of org-mode property drawers.

  Property drawers are special blocks that store key-value pairs associated with sections.
  They must appear directly under a headline and before any other content.

  ## Format

      * Section Title
        :PROPERTIES:
        :key1: value1
        :key2: value2
        :END:

  ## Metadata

  Org-mode also supports special metadata entries like SCHEDULED, DEADLINE, and CLOSED:

      * Task
        SCHEDULED: <2024-01-15 Mon>
        DEADLINE: <2024-01-20 Sat>
        CLOSED: [2024-01-18 Thu]
  """

  @type properties :: %{String.t() => String.t()}
  @type metadata :: %{
          optional(:scheduled) => Org.Timestamp.t(),
          optional(:deadline) => Org.Timestamp.t(),
          optional(:closed) => Org.Timestamp.t()
        }

  @doc """
  Parses a property drawer block.

  Returns a tuple of `{properties, remaining_lines}` where properties is a map
  of property names to values, and remaining_lines are the lines after the drawer.

  ## Examples

      iex> lines = [":PROPERTIES:", ":key: value", ":END:", "Content"]
      iex> Org.PropertyDrawer.parse_drawer(lines)
      {%{"key" => "value"}, ["Content"]}
  """
  @spec parse_drawer([String.t()]) :: {properties(), [String.t()]}
  def parse_drawer([line | rest]) do
    if property_drawer_start?(line) do
      parse_drawer_properties(rest, %{})
    else
      {%{}, [line | rest]}
    end
  end

  def parse_drawer(lines) do
    {%{}, lines}
  end

  defp parse_drawer_properties([line | rest], properties) do
    trimmed = String.trim(line)

    if trimmed == ":END:" do
      {properties, rest}
    else
      case parse_property_line(line) do
        {key, value} ->
          parse_drawer_properties(rest, Map.put(properties, key, value))

        nil ->
          # Invalid line in property drawer, skip it
          parse_drawer_properties(rest, properties)
      end
    end
  end

  defp parse_drawer_properties([], properties) do
    # Property drawer not properly closed
    {properties, []}
  end

  @doc """
  Parses a single property line.

  Returns `{key, value}` tuple or `nil` if the line is not a valid property.

  ## Examples

      iex> Org.PropertyDrawer.parse_property_line(":key: value")
      {"key", "value"}

      iex> Org.PropertyDrawer.parse_property_line(":Title: My Title")
      {"Title", "My Title"}

      iex> Org.PropertyDrawer.parse_property_line("invalid")
      nil
  """
  @spec parse_property_line(String.t()) :: {String.t(), String.t()} | nil
  def parse_property_line(line) do
    case Regex.run(~r/^\s*:([^:]+):\s*(.*)$/, String.trim(line)) do
      [_, key, value] ->
        {String.trim(key), String.trim(value)}

      nil ->
        nil
    end
  end

  @doc """
  Parses metadata lines (SCHEDULED, DEADLINE, CLOSED).

  Returns a tuple of `{metadata, remaining_lines}`.

  ## Examples

      iex> lines = ["SCHEDULED: <2024-01-15 Mon>", "DEADLINE: <2024-01-20 Sat>", "Content"]
      iex> {metadata, remaining} = Org.PropertyDrawer.parse_metadata(lines)
      iex> metadata.scheduled.date
      ~D[2024-01-15]
      iex> metadata.deadline.date
      ~D[2024-01-20]
      iex> remaining
      ["Content"]
  """
  @spec parse_metadata([String.t()]) :: {metadata(), [String.t()]}
  def parse_metadata(lines) do
    parse_metadata_lines(lines, %{})
  end

  defp parse_metadata_lines([line | rest], metadata) do
    trimmed = String.trim(line)

    cond do
      String.starts_with?(trimmed, "SCHEDULED:") ->
        value = extract_metadata_value(trimmed, "SCHEDULED:")
        parse_metadata_lines(rest, Map.put(metadata, :scheduled, value))

      String.starts_with?(trimmed, "DEADLINE:") ->
        value = extract_metadata_value(trimmed, "DEADLINE:")
        parse_metadata_lines(rest, Map.put(metadata, :deadline, value))

      String.starts_with?(trimmed, "CLOSED:") ->
        value = extract_metadata_value(trimmed, "CLOSED:")
        parse_metadata_lines(rest, Map.put(metadata, :closed, value))

      true ->
        # Not a metadata line, return what we have
        {metadata, [line | rest]}
    end
  end

  defp parse_metadata_lines([], metadata) do
    {metadata, []}
  end

  defp extract_metadata_value(line, prefix) do
    timestamp_str =
      line
      |> String.trim_leading(prefix)
      |> String.trim()

    case Org.Timestamp.parse(timestamp_str) do
      {:ok, timestamp} ->
        timestamp

      {:error, _reason} ->
        # If parsing fails, fall back to string (for backward compatibility)
        timestamp_str
    end
  end

  @doc """
  Renders properties back to org-mode format.

  ## Examples

      iex> props = %{"key1" => "value1", "key2" => "value2"}
      iex> Org.PropertyDrawer.render_properties(props)
      ["  :PROPERTIES:", "  :key1: value1", "  :key2: value2", "  :END:"]
  """
  @spec render_properties(properties()) :: [String.t()]
  def render_properties(properties) when properties == %{} do
    []
  end

  def render_properties(properties) do
    lines =
      properties
      |> Enum.sort_by(fn {key, _} -> key end)
      |> Enum.map(fn {key, value} -> "  :#{key}: #{value}" end)

    ["  :PROPERTIES:" | lines] ++ ["  :END:"]
  end

  @doc """
  Renders metadata back to org-mode format.

  ## Examples

      iex> meta = %{scheduled: "<2024-01-15 Mon>", deadline: "<2024-01-20 Sat>"}
      iex> Org.PropertyDrawer.render_metadata(meta)
      ["  SCHEDULED: <2024-01-15 Mon>", "  DEADLINE: <2024-01-20 Sat>"]
  """
  @spec render_metadata(metadata()) :: [String.t()]
  def render_metadata(metadata) when metadata == %{} do
    []
  end

  def render_metadata(metadata) do
    []
    |> maybe_add_metadata_line(:scheduled, metadata)
    |> maybe_add_metadata_line(:deadline, metadata)
    |> maybe_add_metadata_line(:closed, metadata)
    |> Enum.reverse()
  end

  defp maybe_add_metadata_line(lines, key, metadata) do
    case Map.get(metadata, key) do
      nil ->
        lines

      %Org.Timestamp{} = timestamp ->
        value = Org.Timestamp.to_string(timestamp)
        ["  #{String.upcase(to_string(key))}: #{value}" | lines]

      value when is_binary(value) ->
        ["  #{String.upcase(to_string(key))}: #{value}" | lines]
    end
  end

  @doc """
  Checks if a line starts a property drawer.
  """
  @spec property_drawer_start?(String.t()) :: boolean()
  def property_drawer_start?(line) do
    String.trim(line) == ":PROPERTIES:"
  end

  @doc """
  Checks if a line is a metadata line.
  """
  @spec metadata_line?(String.t()) :: boolean()
  def metadata_line?(line) do
    trimmed = String.trim(line)

    String.starts_with?(trimmed, "SCHEDULED:") or
      String.starts_with?(trimmed, "DEADLINE:") or
      String.starts_with?(trimmed, "CLOSED:")
  end

  @doc """
  Extracts both properties and metadata from lines following a section header.

  Returns `{properties, metadata, remaining_lines}`.

  ## Examples

      iex> lines = [
      ...>   ":PROPERTIES:",
      ...>   ":ID: 12345",
      ...>   ":END:",
      ...>   "SCHEDULED: <2024-01-15 Mon>",
      ...>   "Content"
      ...> ]
      iex> {properties, metadata, remaining} = Org.PropertyDrawer.extract_all(lines)
      iex> properties
      %{"ID" => "12345"}
      iex> metadata.scheduled.date
      ~D[2024-01-15]
      iex> remaining
      ["Content"]
  """
  @spec extract_all([String.t()]) :: {properties(), metadata(), [String.t()]}
  def extract_all(lines) do
    # First check for property drawer
    {properties, after_props} =
      case lines do
        [line | _] ->
          if property_drawer_start?(line) do
            parse_drawer(lines)
          else
            {%{}, lines}
          end

        [] ->
          {%{}, lines}
      end

    # Then check for metadata
    {metadata, remaining} = parse_metadata(after_props)

    {properties, metadata, remaining}
  end
end
