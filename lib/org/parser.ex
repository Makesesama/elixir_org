defmodule Org.Parser do
  defstruct doc: %Org.Document{}, mode: nil

  @type t :: %Org.Parser{
          doc: Org.Document.t(),
          mode: :paragraph | :table | :code_block | :list | nil
        }

  @moduledoc ~S"""
  Parses a text or list of tokens into an `Org.Document`.

  By calling `parse/1`, the lexer is invoked first.
  To parse a file that has already been lexed, pass the tokens to `parse_tokens/2` directly.
  """

  @spec parse(String.t()) :: Org.Document.t()
  def parse(text) do
    text
    |> Org.Lexer.lex()
    |> parse_tokens
  end

  @spec parse_tokens(Org.Parser.t(), list(Org.Lexer.token())) :: Org.Document.t()
  def parse_tokens(parser \\ %Org.Parser{}, tokens)

  def parse_tokens(parser, []) do
    parser
    |> Map.get(:doc)
    |> Org.Document.reverse_recursive()
  end

  def parse_tokens(parser, [token | rest]) do
    token
    |> parse_token(parser)
    |> parse_tokens(rest)
  end

  defp parse_token({:comment, comment}, parser) do
    %Org.Parser{doc: Org.Document.add_comment(parser.doc, comment)}
  end

  # Handle new 5-element tuple format with TODO keyword and priority
  defp parse_token({:section_title, level, title, todo_keyword, priority}, parser) do
    %Org.Parser{doc: Org.Document.add_subsection(parser.doc, level, title, todo_keyword, priority)}
  end

  # Handle 4-element tuple format with TODO keyword (backward compatibility)
  defp parse_token({:section_title, level, title, todo_keyword}, parser) do
    %Org.Parser{doc: Org.Document.add_subsection(parser.doc, level, title, todo_keyword, nil)}
  end

  # Handle legacy 3-element tuple format for backward compatibility
  defp parse_token({:section_title, level, title}, parser) do
    %Org.Parser{doc: Org.Document.add_subsection(parser.doc, level, title, nil, nil)}
  end

  defp parse_token({:empty_line}, parser) do
    %Org.Parser{parser | mode: nil}
  end

  defp parse_token({:text, line}, parser) do
    doc =
      if parser.mode == :paragraph do
        Org.Document.update_content(parser.doc, fn paragraph ->
          Org.Paragraph.prepend_line(paragraph, line)
        end)
      else
        Org.Document.prepend_content(parser.doc, Org.Paragraph.new([line]))
      end

    %Org.Parser{parser | doc: doc, mode: :paragraph}
  end

  defp parse_token({:table_row, cells}, parser) do
    doc =
      if parser.mode == :table do
        Org.Document.update_content(parser.doc, fn table ->
          Org.Table.prepend_row(table, cells)
        end)
      else
        Org.Document.prepend_content(parser.doc, Org.Table.new([cells]))
      end

    %Org.Parser{parser | doc: doc, mode: :table}
  end

  defp parse_token({:begin_src, lang, details}, parser) do
    doc = Org.Document.prepend_content(parser.doc, Org.CodeBlock.new(lang, details))

    %Org.Parser{parser | doc: doc, mode: :code_block}
  end

  defp parse_token({:raw_line, line}, %Org.Parser{mode: :code_block} = parser) do
    doc =
      Org.Document.update_content(parser.doc, fn code_block ->
        Org.CodeBlock.prepend_line(code_block, line)
      end)

    %Org.Parser{parser | doc: doc}
  end

  defp parse_token({:end_src}, %Org.Parser{mode: :code_block} = parser) do
    %Org.Parser{parser | mode: nil}
  end

  defp parse_token({:list_item, indent, ordered, number, content}, parser) do
    item = %Org.List.Item{content: content, indent: indent, ordered: ordered, number: number}

    doc =
      if parser.mode == :list do
        Org.Document.update_content(parser.doc, fn list ->
          Org.List.prepend_item(list, item)
        end)
      else
        Org.Document.prepend_content(parser.doc, Org.List.new([item]))
      end

    %Org.Parser{parser | doc: doc, mode: :list}
  end
end
