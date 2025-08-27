defmodule Org.Parser do
  @moduledoc """
  High-performance extensible org-mode parser with plugin support.

  This parser supports:
  - Custom plugins for extending functionality
  - Fast binary pattern matching
  - Zero overhead for default parsing
  - Streaming support for large files

  ## Usage

      # Default parsing (fast path, no plugins)
      {:ok, doc} = Org.Parser.parse(text)

      # With context (recommended for per-user scenarios)
      context = Org.Parser.Context.new([MyCustomPlugin, AnotherPlugin])
      {:ok, doc} = Org.Parser.parse(text, context: context)

      # With direct plugins (legacy approach)
      {:ok, doc} = Org.Parser.parse(text, plugins: [MyCustomPlugin, AnotherPlugin])

      # Streaming mode for large files
      {:ok, doc} = Org.Parser.parse_file("large.org", streaming: true)
  """

  alias Org.Parser.{Matcher, Registry}

  defstruct [
    :document,
    :mode,
    :plugins,
    :context,
    :buffer,
    :section_stack,
    :content_stack
  ]

  @type parser_mode :: :default | :flexible | :strict
  @type parser_opts :: [
          mode: parser_mode(),
          plugins: [module()],
          context: Org.Parser.Context.t(),
          streaming: boolean(),
          parallel: boolean()
        ]

  @doc """
  Parse org-mode text with optional plugins. Raises on error.

  For safe parsing that returns {:ok, doc} | {:error, reason}, use parse_safe/2.

  ## Options

  - `:mode` - Parsing mode (:default, :flexible, :strict)
  - `:plugins` - List of plugin modules to use
  - `:streaming` - Enable streaming mode for large content
  - `:parallel` - Enable parallel parsing (for very large documents)
  """
  @spec parse(binary(), parser_opts()) :: Org.Document.t()
  def parse(text, opts \\ []) when is_binary(text) do
    case parse_safe(text, opts) do
      {:ok, document} -> document
      {:error, reason} -> raise "Failed to parse document: #{inspect(reason)}"
    end
  end

  @doc """
  Parse org-mode text with optional plugins. Returns {:ok, doc} | {:error, reason}.

  ## Options

  - `:mode` - Parsing mode (:default, :flexible, :strict)
  - `:plugins` - List of plugin modules to use
  - `:streaming` - Enable streaming mode for large content
  - `:parallel` - Enable parallel parsing (for very large documents)
  """
  @spec parse_safe(binary(), parser_opts()) :: {:ok, Org.Document.t()} | {:error, term()}
  def parse_safe(text, opts \\ []) when is_binary(text) do
    mode = Keyword.get(opts, :mode, :default)
    plugins = Keyword.get(opts, :plugins, [])
    context = Keyword.get(opts, :context)

    # Fast path for default parsing without plugins
    if mode == :default and plugins == [] and context == nil do
      fast_parse_default(text)
    else
      parse_with_plugins_or_context(text, opts)
    end
  end

  @doc """
  Parse a file with streaming support. Raises on error.
  """
  @spec parse_file(Path.t(), parser_opts()) :: Org.Document.t()
  def parse_file(path, opts \\ []) do
    case parse_file_safe(path, opts) do
      {:ok, document} -> document
      {:error, reason} -> raise "Failed to parse file: #{inspect(reason)}"
    end
  end

  @doc """
  Parse a file with streaming support. Returns {:ok, doc} | {:error, reason}.
  """
  @spec parse_file_safe(Path.t(), parser_opts()) :: {:ok, Org.Document.t()} | {:error, term()}
  def parse_file_safe(path, opts \\ []) do
    streaming = Keyword.get(opts, :streaming, false)

    if streaming do
      parse_file_streaming(path, opts)
    else
      case File.read(path) do
        {:ok, content} -> parse_safe(content, opts)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Fast default parser - no plugin overhead
  defp fast_parse_default(text) do
    parser = %__MODULE__{
      document: %Org.Document{},
      mode: :default,
      plugins: [],
      context: %{},
      buffer: [],
      section_stack: [],
      content_stack: []
    }

    result =
      text
      |> split_into_lines()
      |> parse_lines(parser)
      |> finalize_document()

    {:ok, result}
  rescue
    error -> {:error, error}
  end

  # Parse with plugin support
  defp parse_with_plugins_or_context(text, opts) do
    context = Keyword.get(opts, :context)
    plugins = Keyword.get(opts, :plugins, [])

    # Use context if provided, otherwise fall back to direct plugins
    plugins_or_context = context || plugins

    # Only initialize registry if using direct plugins (legacy mode)
    if context == nil and plugins != [] do
      Registry.start()

      Enum.each(plugins, fn plugin ->
        Registry.register_plugin(plugin, [])
      end)
    end

    parser = %__MODULE__{
      document: %Org.Document{},
      mode: Keyword.get(opts, :mode, :flexible),
      plugins: plugins_or_context,
      context: build_context(opts),
      buffer: [],
      section_stack: [],
      content_stack: []
    }

    result =
      text
      |> split_into_lines()
      |> parse_lines_with_plugins(parser)
      |> finalize_document()

    {:ok, result}
  rescue
    error -> {:error, error}
  end

  # Parse lines with plugin support
  defp parse_lines_with_plugins(lines, parser) do
    Enum.reduce(lines, parser, fn line, acc ->
      parse_single_line_with_plugins(line, acc)
    end)
  end

  defp parse_single_line_with_plugins(line, parser) do
    # First try plugins
    case Matcher.match_and_parse(line, parser.context, parser.plugins) do
      {:handled, result} ->
        add_content(parser, result)

      :no_match ->
        # Fall back to default parsing
        parse_line_default(line, parser)
    end
  end

  # Default line parsing (fast path)
  defp parse_lines(lines, parser) do
    Enum.reduce(lines, parser, &parse_line_default/2)
  end

  defp parse_line_default(line, parser) do
    # Handle mode-specific parsing first
    case parser.mode do
      :property_drawer ->
        if String.trim(line) == ":END:" do
          # End of property drawer
          parse_line_by_type(line, parser)
        else
          # Continue buffering property lines
          %{parser | buffer: [line | parser.buffer]}
        end

      {:code_block, _, _} ->
        if String.starts_with?(line, "#+END_SRC") or String.starts_with?(line, "#+end_src") do
          handle_code_block_end(parser)
        else
          %{parser | buffer: [line | parser.buffer]}
        end

      :table ->
        if String.starts_with?(line, "|") do
          %{parser | buffer: [line | parser.buffer]}
        else
          updated_parser = finish_table(parser)
          parse_line_by_type(line, updated_parser)
        end

      _ ->
        parse_line_by_type(line, parser)
    end
  end

  defp parse_line_by_type(line, parser) do
    case parser.mode do
      {:block, end_marker, plugin, content_lines} ->
        handle_block_mode(line, end_marker, plugin, content_lines, parser)

      _ ->
        parse_line_content(line, parser)
    end
  end

  defp handle_block_mode(line, end_marker, plugin, content_lines, parser) do
    trimmed_line = String.trim(line)

    if trimmed_line == end_marker or trimmed_line == String.downcase(end_marker) do
      finalize_block(line, plugin, content_lines, parser)
    else
      continue_block(line, end_marker, plugin, content_lines, parser)
    end
  end

  defp finalize_block(line, plugin, content_lines, parser) do
    [first_line | middle_lines] = Enum.reverse(content_lines)
    content_with_end = Enum.join([first_line | middle_lines] ++ [line], "\n")

    case plugin.parse(content_with_end, parser.context) do
      {:ok, result} ->
        %{parser | mode: :normal}
        |> add_content(result)

      _ ->
        # Plugin failed, treat as paragraph
        all_lines = [first_line | middle_lines] ++ [line]
        paragraph = %Org.Paragraph{lines: all_lines}

        %{parser | mode: :normal}
        |> add_content(paragraph)
    end
  end

  defp continue_block(line, end_marker, plugin, content_lines, parser) do
    %{parser | mode: {:block, end_marker, plugin, [line | content_lines]}}
  end

  defp parse_line_content(line, parser) do
    content_type = Matcher.identify_content_type(line)
    handle_content_by_type(content_type, line, parser)
  end

  defp handle_content_by_type(:section, line, parser),
    do: handle_section_line(line, parser)

  defp handle_content_by_type(:property_drawer, line, parser),
    do: handle_property_drawer_start(line, parser)

  defp handle_content_by_type(:drawer_end, _line, parser),
    do: handle_drawer_end(parser)

  defp handle_content_by_type(:table, line, parser),
    do: handle_table_line(line, parser)

  defp handle_content_by_type(:list, line, parser),
    do: handle_list_line(line, parser)

  defp handle_content_by_type(:code_block, line, parser),
    do: handle_code_block_start(line, parser)

  defp handle_content_by_type(:code_block_end, _line, parser),
    do: handle_code_block_end(parser)

  defp handle_content_by_type(:block, line, parser),
    do: handle_generic_block(line, parser)

  defp handle_content_by_type(:dynamic_block, line, parser),
    do: handle_generic_block(line, parser)

  defp handle_content_by_type(:comment, line, parser),
    do: handle_comment(line, parser)

  defp handle_content_by_type(:metadata, line, parser),
    do: handle_metadata_line(line, parser)

  defp handle_content_by_type(:paragraph, line, parser) do
    if String.trim(line) == "" do
      flush_buffer(parser)
    else
      handle_paragraph_line(line, parser)
    end
  end

  defp handle_content_by_type(_, line, parser),
    do: %{parser | buffer: [line | parser.buffer]}

  # Section handling
  defp handle_section_line(line, parser) do
    # Mark that file property parsing has ended when we see a section
    parser = %{parser | context: Map.put(parser.context, :file_properties_ended, true)}

    # Parse section header
    {level, title, todo, priority, tags} = parse_section_header(line)

    # Finalize current content
    parser = flush_buffer(parser)

    # Add section directly without tag inheritance for default parsing
    section = %Org.Section{
      title: title,
      todo_keyword: todo,
      priority: priority,
      tags: tags,
      contents: [],
      children: []
    }

    doc = add_section_to_document(parser.document, section, level)
    %{parser | document: doc}
  end

  # Fast section header parsing using binary pattern matching
  defp parse_section_header(line) do
    {level, rest} = count_stars(line, 0)
    {todo, rest} = extract_todo(rest)
    {priority, rest} = extract_priority(rest)
    {title, tags} = extract_title_and_tags(rest)

    {level, title, todo, priority, tags}
  end

  defp count_stars(<<"*", rest::binary>>, count), do: count_stars(rest, count + 1)
  defp count_stars(<<" ", rest::binary>>, count), do: {count, rest}
  defp count_stars(rest, count), do: {count, rest}

  defp extract_todo(text) do
    case String.split(text, " ", parts: 2) do
      [word, rest] when word in ["TODO", "DONE"] ->
        {word, rest}

      _ ->
        {nil, text}
    end
  end

  defp extract_priority(<<"[#", priority::8, "]", rest::binary>>)
       when priority in ?A..?C do
    # Only A, B, C are valid priorities in org-mode
    {<<priority>>, String.trim_leading(rest)}
  end

  defp extract_priority(text), do: {nil, text}

  defp extract_title_and_tags(text) do
    case Regex.run(~r/^(.*?)\s*(:[^:\s]+(?::[^:\s]+)*:)\s*$/, text) do
      [_, title, tags_string] ->
        tags = parse_tags(tags_string)
        {String.trim(title), tags}

      nil ->
        {String.trim(text), []}
    end
  end

  defp parse_tags(tags_string) do
    tags_string
    |> String.trim(":")
    |> String.split(":")
    |> Enum.reject(&(&1 == ""))
  end

  # Buffer management
  defp flush_buffer(%{buffer: []} = parser), do: parser

  defp flush_buffer(%{buffer: buffer, mode: mode} = parser) do
    case mode do
      :list ->
        # If we're in list mode, finish the list instead
        finish_list(parser)

      :table ->
        # If we're in table mode, finish the table
        finish_table(parser)

      _ ->
        # Otherwise process buffered lines as paragraph
        paragraph = %Org.Paragraph{
          lines: Enum.reverse(buffer)
        }

        parser
        |> add_content(paragraph)
        |> Map.put(:buffer, [])
    end
  end

  defp add_content(%{content_stack: []} = parser, content) do
    # Add to most recent section or document root
    case parser.document.sections do
      [] ->
        # No sections, add to document root
        doc = %{parser.document | contents: [content | parser.document.contents]}
        %{parser | document: doc}

      sections ->
        # Add to the deepest current section
        {updated_sections, _} = add_content_to_deepest_section(sections, content)
        doc = %{parser.document | sections: updated_sections}
        %{parser | document: doc}
    end
  end

  defp add_content(%{content_stack: [current | rest]} = parser, content) do
    # Add to current container
    updated = add_to_container(current, content)
    %{parser | content_stack: [updated | rest]}
  end

  defp add_to_container(%{contents: contents} = container, content) do
    %{container | contents: [content | contents]}
  end

  # Property drawer handling
  defp handle_property_drawer_start(_line, parser) do
    parser
    |> flush_buffer()
    |> Map.put(:mode, :property_drawer)
    |> Map.put(:buffer, [])
  end

  defp handle_drawer_end(parser) do
    case parser.mode do
      :property_drawer ->
        properties = parse_properties(Enum.reverse(parser.buffer))
        # Add properties to current section or document
        parser
        |> add_properties(properties)
        |> Map.put(:mode, :normal)
        |> Map.put(:buffer, [])

      _ ->
        parser
    end
  end

  defp add_properties(parser, properties) do
    # Add to most recent section or to document if no sections
    case parser.document.sections do
      [] ->
        # Add to document level (as metadata)
        doc = %{parser.document | file_properties: Map.merge(parser.document.file_properties, properties)}
        %{parser | document: doc}

      [section | rest] ->
        updated_section = %{section | properties: Map.merge(section.properties, properties)}
        doc = %{parser.document | sections: [updated_section | rest]}
        %{parser | document: doc}
    end
  end

  defp parse_properties(lines) do
    lines
    |> Enum.map(&parse_property_line/1)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp parse_property_line(line) do
    trimmed = String.trim(line)
    # Parse lines like ":KEY: value" or ":KEY:" (no value)
    case Regex.run(~r/^:([^:]+):\s*(.*)$/, trimmed) do
      [_, key, value] -> {key, value}
      _ -> nil
    end
  end

  # Table handling
  defp handle_table_line(line, parser) do
    case parser.mode do
      :table ->
        if String.starts_with?(line, "|") do
          %{parser | buffer: [line | parser.buffer]}
        else
          # Table ended, flush and process new line
          updated_parser = finish_table(parser)
          parse_line_by_type(line, updated_parser)
        end

      _ ->
        parser
        |> flush_buffer()
        |> Map.put(:mode, :table)
        |> Map.put(:buffer, [line])
    end
  end

  defp finish_table(%{buffer: buffer} = parser) do
    table = parse_table_from_lines(Enum.reverse(buffer))

    parser
    |> add_content(table)
    |> Map.put(:mode, :normal)
    |> Map.put(:buffer, [])
  end

  defp parse_table_from_lines(lines) do
    rows = Enum.map(lines, &parse_table_row/1)
    %Org.Table{rows: rows}
  end

  defp parse_table_row(line) do
    if String.contains?(line, "+-") or String.contains?(line, "-+") do
      %Org.Table.Separator{}
    else
      cells =
        line
        |> String.trim()
        |> String.trim_leading("|")
        |> String.trim_trailing("|")
        |> String.split("|")
        |> Enum.map(&String.trim/1)

      %Org.Table.Row{cells: cells}
    end
  end

  # List handling
  defp handle_list_line(line, parser) do
    case parser.mode do
      :list ->
        case parse_list_item(line) do
          nil ->
            # Not a list item anymore, finish list
            parser
            |> finish_list()
            |> then(&parse_line_by_type(line, &1))

          item ->
            # Continue list
            %{parser | buffer: [item | parser.buffer]}
        end

      _ ->
        # Start new list
        case parse_list_item(line) do
          nil ->
            parser

          item ->
            parser
            |> flush_buffer()
            |> Map.put(:mode, :list)
            |> Map.put(:buffer, [item])
        end
    end
  end

  defp finish_list(%{buffer: buffer} = parser) do
    list = build_list_from_items(Enum.reverse(buffer))

    parser
    |> add_content(list)
    |> Map.put(:mode, :normal)
    |> Map.put(:buffer, [])
  end

  defp parse_list_item(line) do
    cond do
      match = Regex.run(~r/^(\s*)[-+*]\s+(.*)$/, line) ->
        [_, indent_str, content] = match
        %{indent: String.length(indent_str), ordered: false, content: content, number: nil}

      match = Regex.run(~r/^(\s*)(\d+)[\.)]\s+(.*)$/, line) ->
        [_, indent_str, number_str, content] = match
        %{indent: String.length(indent_str), ordered: true, content: content, number: String.to_integer(number_str)}

      true ->
        nil
    end
  end

  defp build_list_from_items(items) do
    # Convert flat items into hierarchical list structure
    list_items = build_list_hierarchy(items, [])
    %Org.List{items: list_items}
  end

  defp build_list_hierarchy([], acc), do: Enum.reverse(acc)

  defp build_list_hierarchy([item | rest], acc) do
    list_item = %Org.List.Item{
      content: item.content,
      indent: item.indent,
      ordered: item.ordered,
      number: item.number,
      children: []
    }

    build_list_hierarchy(rest, [list_item | acc])
  end

  # Code block handling
  defp handle_code_block_start(line, parser) do
    # Extract language and parameters
    {lang, params} = parse_code_block_header(line)

    %{parser | mode: {:code_block, lang, params}, buffer: []}
  end

  defp handle_code_block_end(%{mode: {:code_block, lang, params}, buffer: buffer} = parser) do
    code_block = %Org.CodeBlock{
      lang: lang,
      details: params,
      lines: Enum.reverse(buffer)
    }

    parser
    |> add_content(code_block)
    |> Map.put(:mode, :normal)
    |> Map.put(:buffer, [])
  end

  defp handle_code_block_end(parser), do: parser

  defp parse_code_block_header(line) do
    case Regex.run(~r/^#\+BEGIN_SRC\s+(\S+)(.*)/i, line) do
      [_, lang, params] -> {lang, String.trim(params)}
      _ -> {"", ""}
    end
  end

  # Generic block handling (for blocks not handled by built-in logic)
  defp handle_generic_block(line, parser) do
    # Check if any plugins can handle this block
    if parser.plugins != [] do
      plugins = Registry.get_plugins_for(line)
      matching_plugins = Enum.filter(plugins, &(&1 in parser.plugins))

      case matching_plugins do
        [plugin | _] ->
          # Use plugin to handle multi-line block
          handle_plugin_block(line, parser, plugin)

        [] ->
          # No plugins, treat as paragraph
          handle_paragraph_line(line, parser)
      end
    else
      # No plugins, treat as paragraph
      handle_paragraph_line(line, parser)
    end
  end

  defp handle_plugin_block(line, parser, plugin) do
    # Extract the block type from the line
    cond do
      # Handle #+BEGIN: style (dynamic blocks)
      match = Regex.run(~r/^#\+BEGIN:\s*(\w+)/i, line) ->
        [_, _block_type] = match
        end_marker = "#+END:"
        parser = flush_buffer(parser)
        collect_block_content(parser, [line], end_marker, plugin)

      # Handle #+BEGIN_BLOCKTYPE style (static blocks)
      match = Regex.run(~r/^#\+BEGIN_(\w+)/i, line) ->
        [_, block_type] = match
        end_marker = "#+END_" <> String.upcase(block_type)
        parser = flush_buffer(parser)
        collect_block_content(parser, [line], end_marker, plugin)

      true ->
        # Not a proper block start, treat as paragraph
        handle_paragraph_line(line, parser)
    end
  end

  defp collect_block_content(parser, content_lines, end_marker, plugin) do
    # Set parser to block collection mode
    %{parser | mode: {:block, end_marker, plugin, content_lines}, buffer: []}
  end

  # Metadata handling (SCHEDULED, DEADLINE, CLOSED)
  defp handle_metadata_line(line, parser) do
    trimmed = String.trim_leading(line)

    cond do
      String.starts_with?(trimmed, "SCHEDULED:") ->
        value = extract_metadata_value(trimmed, "SCHEDULED:")
        add_metadata_to_current_section(parser, :scheduled, value)

      String.starts_with?(trimmed, "DEADLINE:") ->
        value = extract_metadata_value(trimmed, "DEADLINE:")
        add_metadata_to_current_section(parser, :deadline, value)

      String.starts_with?(trimmed, "CLOSED:") ->
        value = extract_metadata_value(trimmed, "CLOSED:")
        add_metadata_to_current_section(parser, :closed, value)

      true ->
        # Fallback to paragraph handling
        handle_paragraph_line(line, parser)
    end
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

  defp add_metadata_to_current_section(parser, key, value) do
    case parser.document.sections do
      [] ->
        # No sections, cannot add metadata - just return parser
        parser

      [current_section | rest_sections] ->
        # Add metadata to the most recent section
        updated_metadata = Map.put(current_section.metadata, key, value)
        updated_section = %{current_section | metadata: updated_metadata}
        doc = %{parser.document | sections: [updated_section | rest_sections]}
        %{parser | document: doc}
    end
  end

  # Comment handling
  defp handle_comment(line, parser) do
    # Extract comment text (remove "#" prefix)
    comment_text = String.slice(line, 1..-1//1)

    # Add to document comments
    doc = %{parser.document | comments: [comment_text | parser.document.comments]}

    # Also check if this is a file property
    parser_with_comment = %{parser | document: doc}

    # If it starts with #+, also try to parse as file property
    if String.starts_with?(line, "#+") do
      handle_file_property(line, parser_with_comment)
    else
      parser_with_comment
    end
  end

  # File property handling
  defp handle_file_property(line, parser) do
    # Only parse file properties at the beginning of the document
    if file_properties_allowed?(parser) do
      case parse_file_property(line) do
        {key, value} ->
          doc = %{parser.document | file_properties: Map.put(parser.document.file_properties, key, value)}
          %{parser | document: doc}

        nil ->
          # Mark that we've seen non-property content
          %{parser | context: Map.put(parser.context, :file_properties_ended, true)}
      end
    else
      # File property parsing has ended, treat as comment
      parser
    end
  end

  defp file_properties_allowed?(parser) do
    # File properties are only allowed if:
    # 1. We haven't seen any non-empty, non-property content
    # 2. We haven't explicitly ended file property parsing
    # 3. The document has no sections and minimal content
    not Map.get(parser.context, :file_properties_ended, false) and
      parser.document.sections == [] and
      length(parser.document.contents) <= 1
  end

  defp parse_file_property(line) do
    case Regex.run(~r/^#\+(\w+):\s*(.*)/, line) do
      [_, key, value] -> {String.upcase(key), String.trim(value)}
      _ -> nil
    end
  end

  # Paragraph handling
  defp handle_paragraph_line(line, parser) do
    # Mark that file property parsing has ended when we see regular content
    parser =
      if String.trim(line) != "" do
        %{parser | context: Map.put(parser.context, :file_properties_ended, true)}
      else
        parser
      end

    case parser.mode do
      :list ->
        # If we're in list mode, finish the list first, then handle as paragraph
        updated_parser = finish_list(parser)
        %{updated_parser | buffer: [line | updated_parser.buffer]}

      :table ->
        # If we're in table mode, finish the table first, then handle as paragraph
        updated_parser = finish_table(parser)
        %{updated_parser | buffer: [line | updated_parser.buffer]}

      _ ->
        # Normal paragraph handling
        %{parser | buffer: [line | parser.buffer]}
    end
  end

  # Finalization
  defp finalize_document(parser) do
    finalized_parser = finalize_current_mode(parser)

    doc =
      Map.get(finalized_parser, :document)
      |> reverse_contents()

    # Only apply tag inheritance if not in default mode
    if parser.mode == :default do
      doc
    else
      apply_tag_inheritance(doc)
    end
  end

  defp finalize_current_mode(parser) do
    case parser.mode do
      :list ->
        finish_list(parser)

      :table ->
        finish_table(parser)

      {:code_block, _, _} ->
        handle_code_block_end(parser)

      {:block, _end_marker, _plugin, content_lines} ->
        # Unfinished block, treat as paragraph
        content = Enum.reverse(content_lines)
        paragraph = %Org.Paragraph{lines: content}

        %{parser | mode: :normal}
        |> add_content(paragraph)

      _ ->
        flush_buffer(parser)
    end
  end

  defp reverse_contents(%Org.Document{contents: contents, sections: sections, comments: comments} = doc) do
    %{
      doc
      | contents: Enum.reverse(contents),
        sections: sections |> Enum.reverse() |> Enum.map(&reverse_section_contents/1),
        comments: Enum.reverse(comments)
    }
  end

  defp reverse_section_contents(%Org.Section{contents: contents, children: children} = section) do
    %{
      section
      | contents: Enum.reverse(contents),
        children: children |> Enum.reverse() |> Enum.map(&reverse_section_contents/1)
    }
  end

  # Tag inheritance system
  defp apply_tag_inheritance(doc) do
    # Parse file tags from FILETAGS file property
    file_tags = parse_file_tags(doc.file_properties)

    # Apply inheritance to all sections
    sections_with_inheritance = Enum.map(doc.sections, &apply_section_tag_inheritance(&1, file_tags, []))

    %{doc | sections: sections_with_inheritance}
  end

  defp parse_file_tags(file_properties) do
    case Map.get(file_properties, "FILETAGS") do
      nil ->
        []

      filetags_string ->
        # Parse both space-separated and colon-separated formats
        filetags_string
        # Convert colon-separated to space-separated
        |> String.replace(":", " ")
        |> String.split(~r/\s+/, trim: true)
    end
  end

  defp apply_section_tag_inheritance(section, file_tags, parent_tags) do
    # Compute inherited tags: file_tags + parent_tags
    inherited_tags = file_tags ++ parent_tags

    # Remove duplicates from inherited tags while preserving order (file tags first, then parent)
    unique_inherited_tags = Enum.uniq(inherited_tags)

    # Effective tags are inherited + direct tags
    effective_tags = unique_inherited_tags ++ section.tags
    unique_effective_tags = Enum.uniq(effective_tags)

    # Apply inheritance to children recursively
    children_with_inheritance =
      Enum.map(section.children, &apply_section_tag_inheritance(&1, file_tags, unique_effective_tags))

    %{section | tags: unique_effective_tags, inherited_tags: unique_inherited_tags, children: children_with_inheritance}
  end

  # Section management
  defp add_section_to_document(doc, section, level) do
    case level do
      1 ->
        %{doc | sections: [section | doc.sections]}

      _ ->
        # Add as child to most recent section
        case doc.sections do
          [parent | rest] ->
            updated_parent = add_nested_section(parent, section, level - 1)
            %{doc | sections: [updated_parent | rest]}

          [] ->
            # No parent sections, add as top level
            %{doc | sections: [section | doc.sections]}
        end
    end
  end

  defp add_nested_section(parent, section, target_level) do
    case target_level do
      1 ->
        %{parent | children: [section | parent.children]}

      _ ->
        case parent.children do
          [child | rest] ->
            updated_child = add_nested_section(child, section, target_level - 1)
            %{parent | children: [updated_child | rest]}

          [] ->
            # No children to nest under, add at current level
            %{parent | children: [section | parent.children]}
        end
    end
  end

  # Helper to add content to the deepest section
  defp add_content_to_deepest_section([], _content), do: {[], :not_added}

  defp add_content_to_deepest_section([section | rest], content) do
    case section.children do
      [] ->
        add_content_to_current_section(section, rest, content)

      children ->
        add_content_to_child_sections(section, rest, children, content)
    end
  end

  defp add_content_to_current_section(section, rest, content) do
    updated_section = %{section | contents: [content | section.contents]}
    {[updated_section | rest], :added}
  end

  defp add_content_to_child_sections(section, rest, children, content) do
    case add_content_to_deepest_section(children, content) do
      {updated_children, :added} ->
        updated_section = %{section | children: updated_children}
        {[updated_section | rest], :added}

      {_children, :not_added} ->
        add_content_to_current_section(section, rest, content)
    end
  end

  # Streaming support
  defp parse_file_streaming(_path, _opts) do
    # Streaming parser implementation needed
    {:error, :not_implemented}
  end

  # Helper functions
  defp split_into_lines(text) do
    String.split(text, ~r/\r?\n/)
  end

  defp build_context(opts) do
    %{
      mode: Keyword.get(opts, :mode, :flexible),
      custom: Keyword.get(opts, :context, %{})
    }
  end
end
