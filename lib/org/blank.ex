defmodule Org.Blank do
  defstruct count: 1

  @type t :: %Org.Blank{
          count: pos_integer()
        }

  @moduledoc ~S"""
  Represents one or more consecutive blank lines between content blocks.

  Blank-line nodes exist so that `Org.Writer.to_org_string/1` can reproduce the
  exact vertical spacing of a parsed document (round-trip fidelity). They carry
  no semantic content and are skipped by most consumers (e.g. JSON export).

  Example:
      iex> doc = Org.Parser.parse("* A\n\nbody\n")
      iex> Org.section(doc, ["A"]).contents
      [%Org.Blank{count: 1}, %Org.Paragraph{lines: ["body"]}]
  """

  @doc "Constructs a blank-line node with the given count (defaults to 1)."
  @spec new(pos_integer()) :: t
  def new(count \\ 1) when is_integer(count) and count >= 1 do
    %Org.Blank{count: count}
  end
end

defimpl Org.Content, for: Org.Blank do
  def content_type(_), do: :blank
  def reverse_recursive(blank), do: blank
  def can_merge?(%Org.Blank{}, %Org.Blank{}), do: true
  def can_merge?(_, _), do: false
  def merge(%Org.Blank{count: a}, %Org.Blank{count: b}), do: %Org.Blank{count: a + b}
  def validate(%Org.Blank{count: n} = blank) when is_integer(n) and n >= 1, do: {:ok, blank}
  def validate(_), do: {:error, "Invalid blank node"}
  def to_text(_), do: ""
  def metadata(%Org.Blank{count: n}), do: %{line_count: n}
  def empty?(_), do: true
end
