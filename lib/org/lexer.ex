defmodule Org.Lexer do
  defstruct tokens: [], mode: :normal

  @type token ::
          {:comment, String.t()}
          | {:section_title, integer, String.t(), String.t() | nil, String.t() | nil}
          | {:table_row, list(String.t())}
          | {:list_item, non_neg_integer(), boolean(), integer() | nil, String.t()}
          | {:empty_line}
          | {:text, String.t()}

  @type t :: %Org.Lexer{
          tokens: list(token),
          mode: :normal | :raw
        }

  @moduledoc ~S"""
  Splits an org-document into tokens.

  For many simple tasks, using the lexer is enough, and a full-fledged `Org.Document` is not needed.

  Usage example:
      iex> source = "#+TITLE: Greetings\n\n* TODO [#A] Hello\n** DONE [#B] World\n** Universe\n* Goodbye\n"
      iex> Org.Lexer.lex(source)
      [{:comment, "+TITLE: Greetings"},
       {:empty_line},
       {:section_title, 1, "Hello", "TODO", "A"},
       {:section_title, 2, "World", "DONE", "B"},
       {:section_title, 2, "Universe", nil, nil},
       {:section_title, 1, "Goodbye", nil, nil},
       {:empty_line}]
  """

  @spec lex(String.t()) :: list(token)
  def lex(text) do
    text
    |> String.split("\n")
    |> lex_lines
    |> Map.get(:tokens)
    |> Enum.reverse()
  end

  defp lex_lines(lexer \\ %Org.Lexer{}, lines)

  defp lex_lines(lexer, []) do
    lexer
  end

  defp lex_lines(lexer, [line | rest]) do
    line
    |> lex_line(lexer)
    |> lex_lines(rest)
  end

  @begin_src_re ~r/^#\+BEGIN_SRC(?:\s+([^\s]*)\s?(.*)|)$/
  @end_src_re ~r/^#\+END_SRC$/
  @comment_re ~r/^#(.+)$/
  @section_title_re ~r/^(\*+)(?:\s+(?:(TODO|DONE)\s+)?(?:\[#([ABC])\]\s+)?(.*))?$/
  @empty_line_re ~r/^\s*$/
  @table_row_re ~r/^\s*(?:\|[^|]*)+\|\s*$/
  @unordered_list_re ~r/^(\s*)[-+]\s+(.+)$/
  @ordered_list_re ~r/^(\s*)(\d+)[\.)]\s+(.+)$/

  defp lex_line(line, %Org.Lexer{mode: :normal} = lexer) do
    cond do
      match = Regex.run(@begin_src_re, line) -> handle_begin_src(lexer, match)
      match = Regex.run(@comment_re, line) -> handle_comment(lexer, match)
      match = Regex.run(@section_title_re, line) -> parse_section_title_match(lexer, match)
      Regex.run(@empty_line_re, line) -> append_token(lexer, {:empty_line})
      Regex.run(@table_row_re, line) -> handle_table_row(lexer, line)
      match = Regex.run(@unordered_list_re, line) -> handle_unordered_list(lexer, match)
      match = Regex.run(@ordered_list_re, line) -> handle_ordered_list(lexer, match)
      true -> append_token(lexer, {:text, line})
    end
  end

  defp lex_line(line, %Org.Lexer{mode: :raw} = lexer) do
    if Regex.run(@end_src_re, line) do
      append_token(lexer, {:end_src}) |> set_mode(:normal)
    else
      append_token(lexer, {:raw_line, line})
    end
  end

  defp append_token(%Org.Lexer{} = lexer, token) do
    %Org.Lexer{lexer | tokens: [token | lexer.tokens]}
  end

  defp set_mode(%Org.Lexer{} = lexer, mode) do
    %Org.Lexer{lexer | mode: mode}
  end

  defp handle_begin_src(lexer, match) do
    {lang, details} =
      case match do
        [_, lang, details] -> {lang, details}
        [_] -> {"", ""}
        _ -> {"", ""}
      end

    append_token(lexer, {:begin_src, lang, details}) |> set_mode(:raw)
  end

  defp handle_comment(lexer, [_, text]) do
    append_token(lexer, {:comment, text})
  end

  defp handle_table_row(lexer, line) do
    cells =
      ~r/\|(?<cell>[^|]+)/
      |> Regex.scan(line, capture: :all_names)
      |> List.flatten()
      |> Enum.map(&String.trim/1)

    append_token(lexer, {:table_row, cells})
  end

  defp handle_unordered_list(lexer, [_, indent_str, content]) do
    indent = String.length(indent_str)
    append_token(lexer, {:list_item, indent, false, nil, content})
  end

  defp handle_ordered_list(lexer, [_, indent_str, number_str, content]) do
    indent = String.length(indent_str)
    number = String.to_integer(number_str)
    append_token(lexer, {:list_item, indent, true, number, content})
  end

  defp parse_section_title_match(lexer, match) do
    case match do
      # Just asterisks, no content
      [_, nesting] ->
        append_token(lexer, {:section_title, String.length(nesting), "", nil, nil})

      # Full match with all components
      [_, nesting, todo_keyword, priority, title] ->
        title = if title, do: String.trim(title), else: ""
        todo_keyword = if todo_keyword == "", do: nil, else: todo_keyword
        priority = if priority == "", do: nil, else: priority
        append_token(lexer, {:section_title, String.length(nesting), title, todo_keyword, priority})

      # Fallback for any other pattern
      _ ->
        # Extract at least the nesting level and treat rest as title
        [_, nesting | rest] = match
        title = rest |> Enum.filter(& &1) |> Enum.join(" ") |> String.trim()
        append_token(lexer, {:section_title, String.length(nesting), title, nil, nil})
    end
  end
end
