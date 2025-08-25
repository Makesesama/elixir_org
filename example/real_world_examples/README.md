# Real-World Use Cases

Here are practical examples of using the Elixir Org parser in real applications.

## Use Case 1: Documentation Management System

```elixir
defmodule DocManager do
  @doc "Converts API documentation from org to structured data"
  def process_api_docs(org_file_path) do
    doc = Org.load_file(org_file_path)
    
    # Extract API endpoints (sections with specific pattern)
    endpoints = Org.NodeFinder.find_all(doc, fn
      %Org.Section{title: title} -> String.starts_with?(title, "GET ") or 
                                   String.starts_with?(title, "POST ") or
                                   String.starts_with?(title, "PUT ") or
                                   String.starts_with?(title, "DELETE ")
      _ -> false
    end)
    
    # Convert to API spec format
    Enum.map(endpoints, fn endpoint ->
      %{
        method: endpoint.title |> String.split() |> hd(),
        path: endpoint.title |> String.split() |> Enum.at(1),
        description: extract_description(endpoint),
        parameters: extract_parameters_table(endpoint),
        examples: extract_code_blocks(endpoint)
      }
    end)
  end
  
  defp extract_description(%Org.Section{contents: contents}) do
    contents
    |> Enum.find(fn %Org.Paragraph{} -> true; _ -> false end)
    |> case do
      %Org.Paragraph{lines: lines} -> Enum.join(lines, " ")
      _ -> ""
    end
  end
  
  defp extract_parameters_table(%Org.Section{contents: contents}) do
    contents
    |> Enum.find(fn %Org.Table{} -> true; _ -> false end)
    |> case do
      %Org.Table{rows: rows} -> parse_parameter_table(rows)
      _ -> []
    end
  end
  
  defp extract_code_blocks(%Org.Section{contents: contents}) do
    Enum.filter(contents, fn %Org.CodeBlock{} -> true; _ -> false end)
  end
end
```

## Use Case 2: Project Status Dashboard

```elixir
defmodule StatusDashboard do
  @doc "Generates dashboard data from project org files"
  def generate_dashboard(project_files) do
    projects = Enum.map(project_files, fn file ->
      doc = Org.load_file(file)
      
      %{
        name: extract_title(doc),
        todos: count_todos(doc),
        done: count_done(doc), 
        high_priority: count_high_priority(doc),
        last_update: extract_last_update(doc),
        progress_metrics: extract_metrics_table(doc)
      }
    end)
    
    %{
      total_projects: length(projects),
      total_tasks: Enum.sum(Enum.map(projects, &(&1.todos + &1.done))),
      completion_rate: calculate_completion_rate(projects),
      projects: projects
    }
  end
  
  defp extract_title(%Org.Document{comments: comments}) do
    comments
    |> Enum.find(&String.starts_with?(&1, "+TITLE:"))
    |> case do
      "+TITLE: " <> title -> title
      _ -> "Untitled Project"
    end
  end
  
  defp count_todos(doc) do
    Org.NodeFinder.find_all(doc, fn
      %Org.Section{todo_keyword: "TODO"} -> true
      _ -> false
    end)
    |> length()
  end
  
  defp count_done(doc) do
    Org.NodeFinder.find_all(doc, fn
      %Org.Section{todo_keyword: "DONE"} -> true  
      _ -> false
    end)
    |> length()
  end
end
```

## Use Case 3: Meeting Notes Processor

```elixir
defmodule MeetingProcessor do
  @doc "Processes meeting notes and extracts action items"
  def process_meeting_notes(notes_file) do
    doc = Org.load_file(notes_file)
    
    %{
      meeting_info: extract_meeting_info(doc),
      attendees: extract_attendees(doc),
      agenda_items: extract_agenda_items(doc),
      action_items: extract_action_items(doc),
      decisions: extract_decisions(doc),
      next_meeting: extract_next_meeting(doc)
    }
  end
  
  defp extract_action_items(doc) do
    # Find sections marked as TODO or with "Action" in title
    Org.NodeFinder.find_all(doc, fn
      %Org.Section{todo_keyword: "TODO"} -> true
      %Org.Section{title: title} -> String.contains?(String.downcase(title), "action")
      _ -> false
    end)
    |> Enum.map(fn section ->
      %{
        title: section.title,
        assignee: extract_assignee(section),
        due_date: extract_due_date(section),
        priority: section.priority,
        description: extract_section_content(section)
      }
    end)
  end
  
  defp extract_decisions(doc) do
    # Find sections with "Decision" in title
    Org.NodeFinder.find_all(doc, fn
      %Org.Section{title: title} -> String.contains?(String.downcase(title), "decision")
      _ -> false
    end)
    |> Enum.map(&extract_section_content/1)
  end
end
```

## Use Case 4: Content Management for Static Site

```elixir
defmodule StaticSiteGenerator do
  @doc "Converts org files to website content"
  def generate_site(content_dir, output_dir) do
    content_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".org"))
    |> Enum.each(fn file ->
      doc = Org.load_file(Path.join(content_dir, file))
      
      # Convert to different output formats
      generate_html_page(doc, output_dir, file)
      generate_json_data(doc, output_dir, file)
      generate_rss_entry(doc, output_dir, file)
    end)
  end
  
  defp generate_html_page(doc, output_dir, filename) do
    # Extract frontmatter
    title = extract_title(doc)
    date = extract_date(doc)
    tags = extract_tags(doc)
    
    # Convert content to HTML
    html_content = doc
    |> Org.to_org_string()
    |> convert_org_to_html()  # Your HTML conversion logic
    
    # Generate HTML file
    html = build_html_template(title, date, tags, html_content)
    
    output_file = Path.join(output_dir, String.replace(filename, ".org", ".html"))
    File.write!(output_file, html)
  end
  
  defp generate_json_data(doc, output_dir, filename) do
    # Create structured data for API consumption
    data = %{
      title: extract_title(doc),
      date: extract_date(doc),
      tags: extract_tags(doc),
      sections: extract_all_sections(doc),
      word_count: calculate_word_count(doc),
      reading_time: calculate_reading_time(doc)
    }
    
    output_file = Path.join(output_dir, String.replace(filename, ".org", ".json"))
    File.write!(output_file, Jason.encode!(data, pretty: true))
  end
end
```

## Use Case 5: Knowledge Base Search

```elixir
defmodule KnowledgeBase do
  @doc "Indexes org files for full-text search"
  def build_search_index(knowledge_base_dir) do
    knowledge_base_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".org"))
    |> Enum.reduce(%{}, fn file, acc ->
      doc = Org.load_file(Path.join(knowledge_base_dir, file))
      
      # Extract searchable content
      sections = extract_searchable_sections(doc)
      
      # Build index entries
      Map.put(acc, file, %{
        title: extract_title(doc),
        tags: extract_tags(doc),
        sections: sections,
        full_text: Org.to_org_string(doc)
      })
    end)
  end
  
  @doc "Searches knowledge base"  
  def search(index, query) do
    query = String.downcase(query)
    
    Enum.flat_map(index, fn {file, content} ->
      matches = find_matches_in_content(content, query)
      Enum.map(matches, &Map.put(&1, :file, file))
    end)
    |> Enum.sort_by(& &1.relevance, :desc)
  end
  
  defp find_matches_in_content(content, query) do
    # Search in title
    title_matches = if String.contains?(String.downcase(content.title), query) do
      [%{type: :title, content: content.title, relevance: 10}]
    else
      []
    end
    
    # Search in sections
    section_matches = Enum.flat_map(content.sections, fn section ->
      if String.contains?(String.downcase(section.title), query) do
        [%{type: :section, content: section.title, relevance: 5}]
      else
        []
      end
    end)
    
    # Search in full text  
    text_matches = if String.contains?(String.downcase(content.full_text), query) do
      [%{type: :content, content: extract_context(content.full_text, query), relevance: 1}]
    else
      []
    end
    
    title_matches ++ section_matches ++ text_matches
  end
end
```

## Use Case 6: Task Management Integration

```elixir
defmodule TaskManager do
  @doc "Syncs org TODO items with external task management system"
  def sync_with_external_system(org_files, api_client) do
    # Extract all tasks from org files
    all_tasks = Enum.flat_map(org_files, fn file ->
      doc = Org.load_file(file)
      extract_tasks_with_metadata(doc, file)
    end)
    
    # Sync with external system
    Enum.each(all_tasks, fn task ->
      case task.external_id do
        nil -> create_external_task(task, api_client)
        id -> update_external_task(id, task, api_client)
      end
    end)
    
    # Update org files with external IDs
    update_org_files_with_external_ids(all_tasks, org_files)
  end
  
  defp extract_tasks_with_metadata(doc, filename) do
    Org.NodeFinder.find_all(doc, fn
      %Org.Section{todo_keyword: keyword} when keyword in ["TODO", "DOING", "DONE"] -> true
      _ -> false
    end)
    |> Enum.map(fn section ->
      %{
        title: section.title,
        status: section.todo_keyword,
        priority: section.priority,
        file: filename,
        path: Org.NodeFinder.path_to_node(doc, section),
        external_id: extract_external_id(section),
        due_date: extract_due_date(section),
        tags: extract_section_tags(section)
      }
    end)
  end
  
  defp create_external_task(task, api_client) do
    external_task = %{
      title: task.title,
      description: task.description,
      status: map_status_to_external(task.status),
      priority: map_priority_to_external(task.priority),
      due_date: task.due_date,
      tags: task.tags
    }
    
    case api_client.create_task(external_task) do
      {:ok, %{id: external_id}} ->
        # Store mapping for later update of org file
        {:ok, external_id}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

These examples demonstrate how the org parser can be integrated into
real-world applications for:

- **Documentation Systems**: Convert org files to API specs
- **Project Dashboards**: Aggregate status from multiple projects  
- **Meeting Management**: Extract action items and decisions
- **Static Site Generation**: Convert content to web formats
- **Knowledge Management**: Build searchable content indexes
- **Task Management**: Sync with external systems

The parser's ability to both read and write org-mode content makes it
perfect for building sophisticated document management and workflow
automation systems.
