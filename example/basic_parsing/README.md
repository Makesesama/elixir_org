# Basic Org Mode Parsing Example

This example demonstrates basic parsing of org-mode documents.

```elixir
# Parse a simple org document
source = """
#+TITLE: My Project
#+AUTHOR: Developer

* TODO [#A] Important Task
This task has high priority and needs immediate attention.

** DONE [#B] Completed Subtask
This subtask was completed successfully.

** TODO [#C] Pending Subtask
This still needs to be done.

* Resources
Here are some useful resources:

- [[https://elixir-lang.org][Elixir Documentation]]
- *Important* information about /functional programming/
- =Code examples= and ~verbatim text~

| Feature | Status | Priority |
|---------|--------|----------|
| Parser  | Done   | High     |
| Writer  | Done   | High     |
| JSON    | Done   | Medium   |

#+BEGIN_SRC elixir
defmodule Example do
  def hello(name) do
    "Hello, #{name}!"
  end
end
#+END_SRC
"""

# Parse the document
doc = Org.Parser.parse(source)

# Access document properties
IO.inspect(doc.comments, label: "Comments")
IO.inspect(length(doc.sections), label: "Number of sections")

# Find specific sections
main_task = Org.section(doc, ["Important Task"])
IO.inspect(main_task.todo_keyword, label: "Main task TODO")
IO.inspect(main_task.priority, label: "Main task priority")

# Extract all TODO items
todos = Org.todo_items(doc)
IO.puts("TODO items found: #{length(todos)}")
for todo <- todos do
  IO.puts("- #{todo.todo_keyword} [#{todo.priority || "None"}] #{todo.title}")
end

# Extract content by type
tables = Org.tables(doc)
IO.puts("Tables found: #{length(tables)}")

code_blocks = Org.code_blocks(doc)
IO.puts("Code blocks found: #{length(code_blocks)}")

paragraphs = Org.paragraphs(doc)
IO.puts("Paragraphs found: #{length(paragraphs)}")

lists = Org.lists(doc)
IO.puts("Lists found: #{length(lists)}")
```

## Output:
```
Comments: ["+TITLE: My Project", "+AUTHOR: Developer"]
Number of sections: 2
Main task TODO: "TODO"
Main task priority: "A"
TODO items found: 2
- TODO [A] Important Task
- TODO [C] Pending Subtask
Tables found: 1
Code blocks found: 1
Paragraphs found: 3
Lists found: 1
```
