defmodule Org.Lexer do
  defstruct tokens: [], mode: :normal

  @type token :: (
    {:comment, String.t} |
    {:section_title, integer, String.t, String.t | nil, String.t | nil} |
    {:table_row, list(String.t)} |
    {:empty_line} |
    {:text, String.t}
  )

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

  @spec lex(String.t) :: list(token)
  def lex(text) do
    text
    |> String.split("\n")
    |> lex_lines
    |> Map.get(:tokens)
    |> Enum.reverse
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

  @begin_src_re     ~r/^#\+BEGIN_SRC(?:\s+([^\s]*)\s?(.*)|)$/
  @end_src_re       ~r/^#\+END_SRC$/
  @comment_re       ~r/^#(.+)$/
  @section_title_re ~r/^(\*+)\s+(?:(TODO|DONE)\s+)?(?:\[#([ABC])\]\s+)?(.+)$/
  @empty_line_re    ~r/^\s*$/
  @table_row_re     ~r/^\s*(?:\|[^|]*)+\|\s*$/

  defp lex_line(line, %Org.Lexer{mode: :normal} = lexer) do
    cond do
      match = Regex.run(@begin_src_re, line) ->
        [_, lang, details] = match
        append_token(lexer, {:begin_src, lang, details}) |> set_mode(:raw)
      match = Regex.run(@comment_re, line) ->
        [_, text] = match
        append_token(lexer, {:comment, text})
      match = Regex.run(@section_title_re, line) ->
        case match do
          [_, nesting, "", "", title] ->
            append_token(lexer, {:section_title, String.length(nesting), title, nil, nil})
          [_, nesting, todo_keyword, "", title] ->
            append_token(lexer, {:section_title, String.length(nesting), title, todo_keyword, nil})
          [_, nesting, "", priority, title] ->
            append_token(lexer, {:section_title, String.length(nesting), title, nil, priority})
          [_, nesting, todo_keyword, priority, title] ->
            append_token(lexer, {:section_title, String.length(nesting), title, todo_keyword, priority})
        end
      Regex.run(@empty_line_re, line) ->
        append_token(lexer, {:empty_line})
      Regex.run(@table_row_re, line) ->
        cells = ~r/\|(?<cell>[^|]+)/
        |> Regex.scan(line, capture: :all_names)
        |> List.flatten
        |> Enum.map(&String.trim/1)
        append_token(lexer, {:table_row, cells})
      true ->
        append_token(lexer, {:text, line})
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
end
