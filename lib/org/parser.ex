defmodule Org.Parser do
  @moduledoc """
  Enhanced parser that uses the improved Content protocol system.

  Key improvements over the original parser:
  - Centralized content handling logic
  - Better error handling and recovery
  - More flexible content attachment
  - Easier to extend with new content types
  """

  defstruct doc: %Org.Document{}, mode: :normal, context: %{}

  @type t :: %Org.Parser{
          doc: Org.Document.t(),
          mode: :normal | :raw,
          context: map()
        }

  alias Org.ContentBuilder

  @spec parse(String.t()) :: Org.Document.t()
  def parse(text) do
    case parse_safe(text) do
      {:ok, document} -> document
      {:error, reason} -> raise "Failed to parse document: #{inspect(reason)}"
    end
  end

  @spec parse_safe(String.t()) :: {:ok, Org.Document.t()} | {:error, term()}
  def parse_safe(text) do
    result =
      text
      |> Org.Lexer.lex()
      |> parse_tokens()

    {:ok, result}
  rescue
    error -> {:error, error}
  catch
    :throw, error -> {:error, error}
  end

  @spec parse_tokens(list(Org.Lexer.token())) :: Org.Document.t()
  def parse_tokens(tokens) do
    parser = %Org.Parser{}

    tokens
    |> Enum.reduce(parser, &parse_token/2)
    |> finalize_document()
  end

  # Token parsing with improved error handling
  defp parse_token(token, parser) do
    case token do
      {:comment, comment} ->
        handle_comment(parser, comment)

      {:section_title, level, title, todo_keyword, priority} ->
        handle_section(parser, level, title, todo_keyword, priority)

      {:empty_line} ->
        handle_empty_line(parser)

      content_token ->
        handle_content_token(parser, content_token)
    end
  rescue
    error ->
      # Add context to errors for better debugging
      updated_context = Map.put(parser.context, :last_error, {token, error})
      %{parser | context: updated_context}
  end

  defp handle_comment(parser, comment) do
    doc = %{parser.doc | comments: [comment | parser.doc.comments]}
    %{parser | doc: doc}
  end

  defp handle_section(parser, level, title, todo_keyword, priority) do
    # Finalize any pending content before starting a new section
    parser = finalize_current_content(parser)

    doc = Org.Document.add_subsection(parser.doc, level, title, todo_keyword, priority)
    %{parser | doc: doc, mode: :normal}
  end

  defp handle_empty_line(parser) do
    # Empty lines can affect content parsing, let the content builder decide
    context = %{mode: parser.mode, parser_state: parser}

    case get_current_content_list(parser) do
      [] ->
        # No content to affect
        parser

      content_list ->
        case ContentBuilder.handle_content(content_list, {:empty_line}, context) do
          {:handled, new_content_list, new_mode} ->
            update_current_content_list(parser, new_content_list)
            |> Map.put(:mode, new_mode)

          {:unhandled, _} ->
            parser

          {:error, reason} ->
            add_error_to_context(parser, {:empty_line_error, reason})
        end
    end
  end

  defp handle_content_token(parser, token) do
    context = %{mode: parser.mode, parser_state: parser}
    current_content = get_current_content_list(parser)

    case ContentBuilder.handle_content(current_content, token, context) do
      {:handled, new_content_list, new_mode} ->
        update_current_content_list(parser, new_content_list)
        |> Map.put(:mode, new_mode)

      {:unhandled, _} ->
        # Fallback to treating as text if nothing else handles it
        handle_fallback_text(parser, token)

      {:error, reason} ->
        add_error_to_context(parser, {token, reason})
    end
  end

  defp handle_fallback_text(parser, token) do
    # Convert unhandled tokens to text paragraphs as fallback
    text_line =
      case token do
        {:table_row, cells} -> "| " <> Enum.join(cells, " | ") <> " |"
        {:list_item, _indent, _ordered, _number, content} -> "- #{content}"
        {:begin_src, lang, details} -> "#+BEGIN_SRC #{lang} #{details}"
        {:raw_line, line} -> line
        {:end_src} -> "#+END_SRC"
        _ -> inspect(token)
      end

    handle_content_token(parser, {:text, text_line})
  end

  defp finalize_current_content(parser) do
    # Process and validate any pending content
    case get_current_content_list(parser) do
      [] ->
        parser

      content_list ->
        # Merge compatible adjacent content and validate
        processed_content =
          content_list
          |> ContentBuilder.merge_compatible_content()
          |> validate_and_filter_content()

        update_current_content_list(parser, processed_content)
    end
  end

  defp finalize_document(parser) do
    # Final processing before returning document
    parser = finalize_current_content(parser)

    # Reverse everything to correct the order
    doc = Org.Document.reverse_recursive(parser.doc)

    # Check for any errors in the parsing context
    case Map.get(parser.context, :errors, []) do
      [] ->
        doc

      errors ->
        # For now, just return the document but log errors
        # In the future, could return {:ok, doc, warnings: errors}
        IO.warn("Parse warnings: #{inspect(errors)}")
        doc
    end
  end

  # Helper functions for managing content lists

  defp get_current_content_list(parser) do
    case parser.doc.sections do
      [] ->
        parser.doc.contents

      [current_section | _] ->
        get_deepest_section_contents(current_section)
    end
  end

  defp update_current_content_list(parser, new_content_list) do
    case parser.doc.sections do
      [] ->
        doc = %{parser.doc | contents: new_content_list}
        %{parser | doc: doc}

      [current_section | rest_sections] ->
        updated_section = update_deepest_section_contents(current_section, new_content_list)
        doc = %{parser.doc | sections: [updated_section | rest_sections]}
        %{parser | doc: doc}
    end
  end

  defp get_deepest_section_contents(section) do
    case section.children do
      [] -> section.contents
      [deepest | _] -> get_deepest_section_contents(deepest)
    end
  end

  defp update_deepest_section_contents(section, new_contents) do
    case section.children do
      [] ->
        %{section | contents: new_contents}

      [deepest_child | rest_children] ->
        updated_child = update_deepest_section_contents(deepest_child, new_contents)
        %{section | children: [updated_child | rest_children]}
    end
  end

  defp validate_and_filter_content(content_list) do
    content_list
    |> Enum.filter(fn content ->
      case Org.Content.validate(content) do
        {:ok, _} -> true
        # Filter out invalid content
        {:error, _reason} -> false
      end
    end)
    # Remove empty content
    |> Enum.reject(&Org.Content.empty?/1)
  end

  defp add_error_to_context(parser, error) do
    errors = Map.get(parser.context, :errors, [])
    context = Map.put(parser.context, :errors, [error | errors])
    %{parser | context: context}
  end
end
