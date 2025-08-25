# Fragment Parsing Examples

This directory demonstrates the fragment parsing capabilities of the Elixir Org Parser. Fragment parsing allows you to parse partial org-mode content while preserving styling and position information, making it ideal for incremental editing scenarios.

## What is Fragment Parsing?

Fragment parsing enables you to:

- Parse individual lines or sections of org-mode text
- Maintain position tracking for precise editing
- Support incremental updates without losing formatting
- Handle partial or malformed content gracefully

## Features Demonstrated

1. **Basic Fragment Parsing** - Parse individual org elements
2. **Position Tracking** - Track exact positions in source text
3. **Incremental Updates** - Make changes without full re-parsing
4. **Context Preservation** - Maintain formatting and structure
5. **Robust Error Handling** - Handle incomplete or malformed input

## Running the Examples

```bash
# Run the basic fragment parsing example
mix run example/fragment_parsing/basic_usage.exs

# Run the incremental editing example
mix run example/fragment_parsing/incremental_editing.exs

# Run the position tracking example
mix run example/fragment_parsing/position_tracking.exs

# Run the error handling example
mix run example/fragment_parsing/error_handling.exs
```

## Use Cases

Fragment parsing is particularly useful for:

- **Text Editors**: Syntax highlighting and incremental parsing
- **Live Preview**: Real-time updates as users type
- **Content Management**: Editing specific sections without affecting others
- **API Integration**: Processing partial org-mode content from external sources
- **Performance Optimization**: Avoiding full document re-parsing

## Integration with Existing Parser

The fragment parser works seamlessly with the existing full-document parser:

- Uses the same data structures (Section, Paragraph, List, etc.)
- Maintains compatibility with JSON serialization
- Integrates with the write mode functionality
- Supports all org-mode content types

This makes it easy to adopt fragment parsing incrementally in existing applications.