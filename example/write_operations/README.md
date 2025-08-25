# Write Operations Example

This example demonstrates all write operations available in the parser.

```elixir
# Start with a basic document
doc = Org.Parser.parse("* Project\nBasic project structure.")

# 1. ADD OPERATIONS

# Add a new section at root level
doc = Org.add_section(doc, [], "Resources", "TODO", "B")

# Add a child section
doc = Org.add_section(doc, ["Project"], "Development", "TODO", "A")
doc = Org.add_section(doc, ["Project"], "Testing", "TODO", "B")

# Add content to sections
dev_para = %Org.Paragraph{lines: ["Development tasks and milestones."]}
doc = Org.add_content(doc, ["Project", "Development"], dev_para)

# Add a code block
code = %Org.CodeBlock{
  lang: "elixir", 
  details: "",
  lines: ["defmodule MyApp do", "  # Application code", "end"]
}
doc = Org.add_content(doc, ["Project", "Development"], code)

# Add a table
table = %Org.Table{
  rows: [
    %Org.Table.Row{cells: ["Task", "Status", "Assignee"]},
    %Org.Table.Separator{},
    %Org.Table.Row{cells: ["Setup", "Done", "Alice"]},
    %Org.Table.Row{cells: ["Testing", "In Progress", "Bob"]}
  ]
}
doc = Org.add_content(doc, ["Project", "Testing"], table)

# Add a list
list = %Org.List{
  items: [
    %Org.List.Item{content: "Unit tests", indent: 0, ordered: false, children: []},
    %Org.List.Item{content: "Integration tests", indent: 0, ordered: false, children: []},
    %Org.List.Item{content: "Performance tests", indent: 0, ordered: false, children: []}
  ]
}
doc = Org.add_content(doc, ["Resources"], list)

# 2. INSERT OPERATIONS (at specific positions)

# Insert at first position
doc = Org.Writer.insert_section(doc, ["Project"], :first, "Planning", "TODO", "A")

# Insert before a specific section
doc = Org.Writer.insert_section(doc, ["Project"], {:before, "Testing"}, "Implementation", "TODO", "A")

# Insert after a specific section
doc = Org.Writer.insert_section(doc, ["Project"], {:after, "Development"}, "Documentation", "TODO", "C")

# 3. UPDATE OPERATIONS

# Update section properties
doc = Org.update_node(doc, ["Project", "Planning"], fn section ->
  %{section | 
    todo_keyword: "DONE",
    priority: "A"
  }
end)

# Update section title
doc = Org.update_node(doc, ["Resources"], fn section ->
  %{section | title: "Project Resources"}
end)

# 4. MOVE OPERATIONS

# Move a section to a different parent
doc = Org.move_node(doc, ["Project", "Documentation"], ["Project Resources"])

# 5. REMOVE OPERATIONS

# Remove a section (this would remove Implementation)
# doc = Org.remove_node(doc, ["Project", "Implementation"])

# Serialize back to org format
result = Org.to_org_string(doc)
IO.puts(result)
```

## Expected Output:
```org
* Project
Basic project structure.

** DONE [#A] Planning
** TODO [#A] Development
Development tasks and milestones.

#+BEGIN_SRC elixir
defmodule MyApp do
  # Application code
end
#+END_SRC

** TODO [#A] Implementation
** TODO [#B] Testing
| Task | Status | Assignee |
|----------|
| Setup | Done | Alice |
| Testing | In Progress | Bob |

* Project Resources
- Unit tests
- Integration tests
- Performance tests

** TODO [#C] Documentation
```

## Available Write Operations:

### Adding Content
- `Org.add_section/5` - Add section at end of children
- `Org.add_content/3` - Add content to section or document

### Inserting Content
- `Org.Writer.insert_section/6` - Insert at specific position
  - `:first` - At beginning
  - `:last` - At end (same as add)
  - `{:before, title}` - Before specific sibling
  - `{:after, title}` - After specific sibling
  - `index` - At numeric position

### Modifying Content
- `Org.update_node/3` - Update using function
- `Org.move_node/3` - Move to different location
- `Org.remove_node/2` - Remove from document

### Serialization
- `Org.to_org_string/1` - Convert back to org-mode text
