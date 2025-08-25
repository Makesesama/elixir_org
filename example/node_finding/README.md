# Node Finding and Navigation Example

This example shows all the ways to find and navigate nodes in an org document.

```elixir
# Create a sample document with complex structure
source = """
* TODO [#A] Frontend Development
User interface development tasks.

** TODO [#B] Components
Reusable UI components.

*** DONE Button Component
Basic button with styling.

*** TODO Modal Component
Modal dialog implementation.

** TODO [#A] Pages
Application pages and routing.

*** TODO Home Page
Landing page design.

*** TODO Dashboard
User dashboard interface.

* DONE [#B] Backend Development
Server-side development.

** DONE API Design
RESTful API specification.

** TODO Database Schema
Data model design.

* Resources
Development resources and links.
"""

doc = Org.Parser.parse(source)

# 1. BASIC PATH FINDING

# Find by exact path
frontend = Org.find_node(doc, ["Frontend Development"])
IO.puts("Found: #{frontend.title}")

# Find nested nodes
button = Org.find_node(doc, ["Frontend Development", "Components", "Button Component"])
IO.puts("Found: #{button.title} - #{button.todo_keyword}")

# Find using NodeFinder directly
modal = Org.NodeFinder.find_by_path(doc, ["Frontend Development", "Components", "Modal Component"])
IO.puts("Found: #{modal.title}")

# 2. FINDING BY INDEX

# Find first section
first_section = Org.NodeFinder.find_by_path(doc, [{:section, 0}])
IO.puts("First section: #{first_section.title}")

# Find second child of first section
second_child = Org.NodeFinder.find_by_path(doc, ["Frontend Development", {:child, 1}])
IO.puts("Second child: #{second_child.title}")

# 3. FINDING ALL NODES BY CRITERIA

# Find all TODO items
todo_items = Org.NodeFinder.find_all(doc, fn
  %Org.Section{todo_keyword: "TODO"} -> true
  _ -> false
end)

IO.puts("\nTODO Items (#{length(todo_items)}):")
for todo <- todo_items do
  path = Org.NodeFinder.path_to_node(doc, todo)
  IO.puts("- [#{todo.priority || "None"}] #{Enum.join(path, " > ")}")
end

# Find all DONE items
done_items = Org.NodeFinder.find_all(doc, fn
  %Org.Section{todo_keyword: "DONE"} -> true
  _ -> false
end)

IO.puts("\nDONE Items (#{length(done_items)}):")
for done <- done_items do
  path = Org.NodeFinder.path_to_node(doc, done)
  IO.puts("- [#{done.priority || "None"}] #{Enum.join(path, " > ")}")
end

# Find all high priority items (A)
high_priority = Org.NodeFinder.find_all(doc, fn
  %Org.Section{priority: "A"} -> true
  _ -> false
end)

IO.puts("\nHigh Priority Items (#{length(high_priority)}):")
for item <- high_priority do
  IO.puts("- #{item.todo_keyword} #{item.title}")
end

# Find all leaf nodes (sections with no children)
leaf_sections = Org.NodeFinder.find_all(doc, fn
  %Org.Section{children: []} -> true
  _ -> false
end)

IO.puts("\nLeaf Sections (#{length(leaf_sections)}):")
for leaf <- leaf_sections do
  path = Org.NodeFinder.path_to_node(doc, leaf)
  IO.puts("- #{Enum.join(path, " > ")}")
end

# 4. PARENT AND PATH OPERATIONS

# Find parent of a node
{parent, {type, index}} = Org.NodeFinder.find_parent(doc, button)
IO.puts("\nParent of 'Button Component': #{parent.title} (at #{type} #{index})")

# Generate path to node
path_to_modal = Org.NodeFinder.path_to_node(doc, modal)
IO.puts("Path to Modal Component: #{Enum.join(path_to_modal, " > ")}")

# 5. WALKING THE ENTIRE TREE

IO.puts("\nWalking entire document tree:")
Org.NodeFinder.walk(doc, fn
  %Org.Document{}, path ->
    IO.puts("📄 Document (root)")
    
  %Org.Section{title: title, todo_keyword: todo}, path ->
    indent = String.duplicate("  ", length(path) - 1)
    todo_part = if todo, do: " [#{todo}]", else: ""
    IO.puts("#{indent}📁 #{title}#{todo_part}")
    
  %Org.Paragraph{lines: [first_line | _]}, path ->
    indent = String.duplicate("  ", length(path))
    preview = String.slice(to_string(first_line), 0..30)
    IO.puts("#{indent}📝 Paragraph: #{preview}...")
    
  content, path ->
    indent = String.duplicate("  ", length(path))
    type = content.__struct__ |> Module.split() |> List.last()
    IO.puts("#{indent}📄 #{type}")
end)

# 6. PRACTICAL SEARCH FUNCTIONS

# Find sections containing specific text
sections_with_text = Org.NodeFinder.find_all(doc, fn
  %Org.Section{title: title} -> String.contains?(String.downcase(title), "component")
  _ -> false
end)

IO.puts("\nSections containing 'component' (#{length(sections_with_text)}):")
for section <- sections_with_text do
  IO.puts("- #{section.title}")
end

# Find all paragraphs
all_paragraphs = Org.NodeFinder.find_all(doc, fn
  %Org.Paragraph{} -> true
  _ -> false
end)

IO.puts("\nTotal paragraphs found: #{length(all_paragraphs)}")
```

## Expected Output:
```
Found: Frontend Development
Found: Button Component - DONE
Found: Modal Component
First section: Frontend Development
Second child: Pages

TODO Items (7):
- [A] Frontend Development
- [B] Components
- [None] Modal Component
- [A] Pages
- [None] Home Page
- [None] Dashboard
- [None] Database Schema

DONE Items (3):
- [None] Button Component
- [B] Backend Development
- [None] API Design

High Priority Items (2):
- TODO Frontend Development
- TODO Pages

Leaf Sections (7):
- Frontend Development > Components > Button Component
- Frontend Development > Components > Modal Component
- Frontend Development > Pages > Home Page
- Frontend Development > Pages > Dashboard
- Backend Development > API Design
- Backend Development > Database Schema
- Resources

Parent of 'Button Component': Components (at :child 0)
Path to Modal Component: Frontend Development > Components > Modal Component

Walking entire document tree:
📄 Document (root)
  📁 Frontend Development [TODO]
    📝 Paragraph: User interface development task...
    📁 Components [TODO]
      📝 Paragraph: Reusable UI components...
      📁 Button Component [DONE]
        📝 Paragraph: Basic button with styling...
      📁 Modal Component [TODO]
        📝 Paragraph: Modal dialog implementation...
    📁 Pages [TODO]
      📝 Paragraph: Application pages and routing...
      📁 Home Page [TODO]
        📝 Paragraph: Landing page design...
      📁 Dashboard [TODO]
        📝 Paragraph: User dashboard interface...
  📁 Backend Development [DONE]
    📝 Paragraph: Server-side development...
    📁 API Design [DONE]
      📝 Paragraph: RESTful API specification...
    📁 Database Schema [TODO]
      📝 Paragraph: Data model design...
  📁 Resources
    📝 Paragraph: Development resources and lin...

Sections containing 'component' (3):
- Components
- Button Component
- Modal Component

Total paragraphs found: 10
```

## Node Finding Methods Summary:

### Direct Finding
- `Org.find_node(doc, path)` - Find by path
- `Org.NodeFinder.find_by_path(doc, path)` - Same as above
- Path formats: `["Title1", "Title2"]` or `[{:section, 0}, {:child, 1}]`

### Search Operations  
- `Org.NodeFinder.find_all(doc, predicate_fn)` - Find all matching nodes
- `Org.NodeFinder.find_parent(doc, node)` - Find parent and position
- `Org.NodeFinder.path_to_node(doc, node)` - Get path to node

### Tree Navigation
- `Org.NodeFinder.walk(doc, visitor_fn)` - Visit all nodes in tree
- Visitor function receives `(node, path_from_root)`
