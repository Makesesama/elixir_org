# Org-mode to HTML Converter Example

This example demonstrates how to use the `org` library to parse org-mode files and convert them to HTML.

## Files

- `sample.org` - Example org-mode document with various features
- `converter.exs` - Elixir script that converts org files to HTML
- `README.md` - This documentation

## Features Demonstrated

The converter handles:

- **Document Structure**: Nested sections with hierarchical headings
- **TODO Keywords**: TODO/DONE states with visual styling
- **Priorities**: Priority levels [#A], [#B], [#C] with color coding
- **Content Types**:
  - Paragraphs
  - Tables (with proper HTML table structure)
  - Code blocks (with syntax highlighting support)
- **HTML Styling**: Clean, readable CSS styling

## Usage

### Prerequisites

Make sure you have the `org` library available in your Elixir environment:

```bash
# If running from the project root
mix deps.get
```

### Running the Converter

From the `example/org_to_html` directory:

```bash
# Convert sample.org to sample.html
elixir converter.exs sample.org

# Convert to a specific output file
elixir converter.exs sample.org my_document.html
```

### Example Output

The converter will process the sample org file and generate clean HTML with:

- Proper semantic HTML structure (h1, h2, h3 headings)
- Styled TODO/DONE keywords
- Color-coded priority levels
- Formatted tables and code blocks
- Responsive CSS styling

## Customization

You can easily extend the converter by:

1. **Adding new content types**: Extend the `content_to_html/1` function
2. **Custom styling**: Modify the CSS in the HTML template
3. **Additional org features**: Use more functions from the `Org` module
4. **Output formats**: Adapt the conversion logic for other formats

## Example org-mode Input

```org
* TODO [#A] Important Task
This is a high-priority task that needs attention.

** DONE [#B] Completed Subtask
This subtask has been finished.

| Feature | Status | Notes |
|---------+--------+-------|
| Parser  | Done   | Works well |
| Export  | TODO   | In progress |
```

## Example HTML Output

The converter generates semantic HTML with embedded CSS styling, creating a clean, readable document that preserves the structure and meaning of the original org-mode file.