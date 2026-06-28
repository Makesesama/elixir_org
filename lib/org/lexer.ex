defmodule Org.Lexer do
  defstruct tokens: [], mode: :normal

  @type token ::
          {:comment, String.t()}
          | {:section_title, integer, String.t(), String.t() | nil, String.t() | nil, [String.t()]}
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
      iex> source = "#+TITLE: Greetings\n\n* TODO [#A] Hello :work:\n** DONE [#B] World :project:\n** Universe\n* Goodbye\n"
      iex> Org.Lexer.lex(source)
      [{:comment, "+TITLE: Greetings"},
       {:empty_line},
       {:section_title, 1, "Hello", "TODO", "A", ["work"]},
       {:section_title, 2, "World", "DONE", "B", ["project"]},
       {:section_title, 2, "Universe", nil, nil, []},
       {:section_title, 1, "Goodbye", nil, nil, []},
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

  @comment_re ~r/^#(.+)$/
  @empty_line_re ~r/^\s*$/
  defp lex_line(line, %Org.Lexer{mode: :normal} = lexer) do
    cond do
      Org.Syntax.BlockParser.begin_src?(line) -> handle_begin_src(lexer, line)
      match = Regex.run(@comment_re, line) -> handle_comment(lexer, match)
      String.starts_with?(line, "*") -> handle_potential_section_title(lexer, line)
      Regex.run(@empty_line_re, line) -> append_token(lexer, {:empty_line})
      Org.Syntax.TableParser.row?(line) -> handle_table_row(lexer, line)
      match?({:ok, _}, Org.Syntax.ListParser.parse_line(line, allow_star: false)) -> handle_list_item(lexer, line)
      true -> append_token(lexer, {:text, line})
    end
  end

  defp lex_line(line, %Org.Lexer{mode: :raw} = lexer) do
    if Org.Syntax.BlockParser.end_src?(line) do
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

  defp handle_begin_src(lexer, line) do
    {:ok, %{lang: lang, params: details}} = Org.Syntax.BlockParser.parse_line(line)
    append_token(lexer, {:begin_src, lang, details}) |> set_mode(:raw)
  end

  defp handle_comment(lexer, [_, text]) do
    append_token(lexer, {:comment, text})
  end

  defp handle_table_row(lexer, line) do
    cells =
      case Org.Syntax.TableParser.parse_row(line) do
        {:ok, cells} -> cells
        :separator -> []
      end

    append_token(lexer, {:table_row, cells})
  end

  defp handle_list_item(lexer, line) do
    {:ok, item} = Org.Syntax.ListParser.parse_line(line, allow_star: false)
    append_token(lexer, {:list_item, item.indent, item.ordered, item.number, item.content})
  end

  defp handle_potential_section_title(lexer, line) do
    case Org.Syntax.HeadlineParser.parse_line(line) do
      {:ok, headline} ->
        append_token(
          lexer,
          {:section_title, headline.level, headline.title, headline.todo_keyword, headline.priority, headline.tags}
        )

      :error ->
        append_token(lexer, {:text, line})
    end
  end
end
