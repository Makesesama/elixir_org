defmodule Org.Syntax.HeadlineParser do
  @moduledoc """
  NimbleParsec-backed parser for Org headline lines.

  This parser handles the bounded headline prefix syntax (`*+` followed by
  required whitespace) and centralizes TODO keyword, priority, title, and tag
  extraction for higher-level structural parsers.
  """

  import NimbleParsec

  stars = ascii_string([?*], min: 1)
  required_whitespace = ignore(times(ascii_char([?\s, ?\t]), min: 1))
  rest = utf8_string([not: ?\n], min: 0)

  headline = stars |> concat(required_whitespace) |> concat(rest)

  defparsec(:headline_line, headline)

  @type parsed :: %{
          level: pos_integer(),
          title: String.t(),
          todo_keyword: String.t() | nil,
          priority: String.t() | nil,
          tags: [String.t()]
        }

  @spec parse_line(String.t(), keyword()) :: {:ok, parsed()} | :error
  def parse_line(line, opts \\ [])

  def parse_line(line, opts) when is_binary(line) do
    keywords = Keyword.get(opts, :keywords, ["TODO", "DONE"])

    case headline_line(line) do
      {:ok, [stars, rest], "", _context, _line, _offset} ->
        {:ok, parse_components(String.length(stars), rest, keywords)}

      _ ->
        :error
    end
  end

  def parse_line(_, _), do: :error

  defp parse_components(level, rest, keywords) do
    {todo_keyword, rest} = extract_todo_keyword(String.trim_leading(rest), keywords)
    {priority, rest} = extract_priority(String.trim_leading(rest))
    {title, tags} = extract_title_and_tags(rest)

    %{
      level: level,
      title: title,
      todo_keyword: todo_keyword,
      priority: priority,
      tags: tags
    }
  end

  defp extract_todo_keyword(rest, keywords) do
    case String.split(rest, ~r/\s+/, parts: 2) do
      [word, remaining] ->
        if word in keywords do
          {word, remaining}
        else
          {nil, rest}
        end

      [word] ->
        if word in keywords do
          {word, ""}
        else
          {nil, rest}
        end
    end
  end

  defp extract_priority(<<"[#", priority::binary-size(1), "]", rest::binary>>) when priority in ["A", "B", "C"] do
    {priority, rest}
  end

  defp extract_priority(rest), do: {nil, rest}

  defp extract_title_and_tags(text) do
    trimmed = String.trim(text)

    case Regex.run(~r/^(.*?)\s*(:[^:\s]+(?::[^:\s]+)*:)\s*$/, trimmed) do
      [_, title, tags_string] ->
        {String.trim(title), parse_tags(tags_string)}

      nil ->
        {trimmed, []}
    end
  end

  defp parse_tags(tags_string) do
    tags_string
    |> String.trim()
    |> String.trim_leading(":")
    |> String.trim_trailing(":")
    |> String.split(":")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.trim/1)
  end
end
