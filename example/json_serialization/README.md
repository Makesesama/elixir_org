# JSON Serialization Example

This example shows how to convert org-mode documents to JSON format.

## Original Org Content:
```org
* TODO [#A] Project Setup
Initial project configuration and setup.

** DONE Environment Setup
Development environment is ready.

| Task | Status | Time |
|------|--------|------|
| Git  | Done   | 1h   |
| IDE  | Done   | 30m  |

#+BEGIN_SRC bash
mix new my_project
cd my_project
#+END_SRC
```

## Elixir Code:
```elixir
# Parse the document
doc = Org.Parser.parse(source)

# Convert to JSON-encodable map
json_map = Org.to_json_map(doc)

# Alternative using encoder module
json_map2 = Org.encode_json(doc)

# Both methods produce the same result
assert json_map == json_map2

# The JSON map can be encoded with any JSON library
# For example with Jason: Jason.encode!(json_map)
```

## Generated JSON Structure:
```elixir
%{
  type: "document",
  comments: [],
  sections: [
    %{
      priority: "A",
      type: "section",
      title: "Project Setup",
      children: [
        %{
          priority: nil,
          type: "section",
          title: "Environment Setup",
          children: [],
          contents: [
            %{type: "paragraph", lines: ["Development environment is ready."]},
            %{
              type: "table",
              rows: [
                %{type: "table_row", cells: ["Task", "Status", "Time"]},
                %{type: "table_separator"},
                %{type: "table_row", cells: ["Git", "Done", "1h"]},
                %{type: "table_row", cells: ["IDE", "Done", "30m"]}
              ]
            },
            %{
              type: "code_block",
              lines: ["mix new my_project", "cd my_project"],
              details: "",
              lang: "bash"
            }
          ],
          todo_keyword: "DONE"
        }
      ],
      contents: [
        %{
          type: "paragraph",
          lines: ["Initial project configuration and setup."]
        }
      ],
      todo_keyword: "TODO"
    }
  ],
  contents: []
}
```

## Key Features:
- Every struct has a `type` field for easy identification
- All nested structures are properly serialized
- Formatted text maintains span information
- Links preserve URL and description
- Tables include both data rows and separators
- Code blocks maintain language and content
- TODO keywords and priorities are preserved
