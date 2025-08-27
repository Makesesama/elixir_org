defmodule Org.Plugins.CodeBlock do
  @moduledoc """
  Plugin for parsing code blocks with enhanced features.

  Supports:
  - Standard org-mode code blocks
  - Line numbering
  - Language detection
  - Syntax highlighting hints
  """

  use Org.Parser.Plugin

  @impl true
  def patterns do
    [
      "#+BEGIN_SRC",
      "#+begin_src",
      "#+BEGIN_EXAMPLE",
      "#+begin_example"
    ]
  end

  @impl true
  # Higher priority than default
  def priority, do: 50

  @impl true
  def fast_match?(<<"#+", _::binary>>), do: true
  def fast_match?(_), do: false

  @impl true
  def parse(<<"#+BEGIN_SRC", rest::binary>>, context) do
    parse_src_block(rest, context, "SRC")
  end

  def parse(<<"#+begin_src", rest::binary>>, context) do
    parse_src_block(rest, context, "src")
  end

  def parse(<<"#+BEGIN_EXAMPLE", rest::binary>>, context) do
    parse_example_block(rest, context, "EXAMPLE")
  end

  def parse(<<"#+begin_example", rest::binary>>, context) do
    parse_example_block(rest, context, "example")
  end

  def parse(_, _), do: :skip

  # Private functions

  defp parse_src_block(content, _context, end_marker_case) do
    # Extract language and parameters
    {lang, params, remaining} = extract_src_header(content)

    # Find the end marker
    end_marker = "#+END_" <> end_marker_case

    case extract_block_content(remaining, end_marker) do
      {:ok, code_lines, _rest} ->
        code_block = %Org.CodeBlock{
          lang: lang,
          details: params,
          lines: code_lines
        }

        {:ok, code_block}

      :error ->
        {:error, :unclosed_code_block}
    end
  end

  defp parse_example_block(content, _context, end_marker_case) do
    end_marker = "#+END_" <> end_marker_case

    case extract_block_content(content, end_marker) do
      {:ok, lines, _rest} ->
        example_block = %Org.CodeBlock{
          lang: "example",
          details: "",
          lines: lines
        }

        {:ok, example_block}

      :error ->
        {:error, :unclosed_example_block}
    end
  end

  defp extract_src_header(content) do
    case String.split(content, "\n", parts: 2) do
      [header, rest] ->
        {lang, params} = parse_header_line(header)
        {lang, params, rest}

      [header] ->
        {lang, params} = parse_header_line(header)
        {lang, params, ""}
    end
  end

  defp parse_header_line(line) do
    parts = String.split(String.trim(line), " ", parts: 2)

    case parts do
      [lang, params] -> {lang, params}
      [lang] -> {lang, ""}
      [] -> {"", ""}
    end
  end

  defp extract_block_content(content, end_marker) do
    lines = String.split(content, "\n")

    # Skip the first line (BEGIN line) and last empty line if present
    content_lines =
      case lines do
        [_begin_line | rest] ->
          # Remove trailing empty lines
          rest |> Enum.reverse() |> Enum.drop_while(&(&1 == "")) |> Enum.reverse()

        _ ->
          lines
      end

    case find_end_marker(content_lines, end_marker, []) do
      {:found, code_lines, remaining} ->
        {:ok, Enum.reverse(code_lines), remaining}

      :not_found ->
        :error
    end
  end

  defp find_end_marker([], _marker, _acc), do: :not_found

  defp find_end_marker([line | rest], marker, acc) do
    if String.starts_with?(line, marker) do
      {:found, acc, rest}
    else
      find_end_marker(rest, marker, [line | acc])
    end
  end
end
