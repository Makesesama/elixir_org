# Org

[![CI](https://github.com/Makesesama/elixir_org/actions/workflows/ci.yml/badge.svg)](https://github.com/Makesesama/elixir_org/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/org.svg)](https://hex.pm/packages/org)

Implements an org-mode parser.

Further documentation is available [on hexdocs.pm](https://hexdocs.pm/org/Org.html)

## Installation

The package can be installed by adding `org` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:org, github: "Makesesama/elixir_org"}
  ]
end
```

## Quick Start

### Basic Usage

```elixir
# Parse an org-mode document
content = """
#+TITLE: My Document
#+FILETAGS: :example:demo:

* Introduction
This is a sample org document with [[https://example.com][links]].

** TODO Review the documentation
   SCHEDULED: <2024-01-20>
"""

# Parse the document
doc = Org.Parser.parse(content)

# Access document properties
doc.file_properties["TITLE"]  # => "My Document"
length(doc.sections)          # => 1

# Access section details
section = hd(doc.sections)
section.title                 # => "Introduction"
```

### Using Plugins

This library supports plugins for extending functionality through a **plugin registry system**:

#### Plugin Registry

The parser uses an ETS-based registry to manage plugins efficiently:

```elixir
alias Org.Parser.Registry
alias Org.Plugins.{Denote, CodeBlock, DynamicBlock}

# Start the plugin registry (usually in your application startup)
Registry.start()

# Register plugins with the registry
Registry.register_plugin(Denote, [])
Registry.register_plugin(CodeBlock, [])
Registry.register_plugin(DynamicBlock, [])

# Parse with registered plugins automatically used
doc = Org.Parser.parse(content)
```

#### Alternative: Direct Plugin Usage

You can also specify plugins directly without using the registry:

```elixir
# Parse with specific plugins (no registry needed)
doc = Org.Parser.parse(content, plugins: [Denote, CodeBlock])
```

#### Registry Benefits

- **Performance**: Fast pattern-based plugin lookup using ETS
- **Global state**: Register plugins once, use everywhere
- **Priority handling**: Plugins are automatically sorted by priority
- **Pattern optimization**: Efficient content-to-plugin matching

#### Phoenix Integration

If you want to use the registry in your Phoenix project, register plugins in your application startup:

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # ... other children
      MyAppWeb.Endpoint
    ]

    # Start the Org parser registry and register plugins
    Org.Parser.Registry.start()
    Org.Parser.Registry.register_plugin(Org.Plugins.Denote, [])
    Org.Parser.Registry.register_plugin(Org.Plugins.CodeBlock, [])
    Org.Parser.Registry.register_plugin(Org.Plugins.DynamicBlock, [])

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Then use the parser anywhere in your Phoenix app:

```elixir
# In controllers, live views, contexts, etc.
defmodule MyAppWeb.NoteController do
  def show(conn, %{"content" => org_content}) do
    # Plugins are automatically available
    doc = Org.Parser.parse(org_content)
    
    render(conn, "show.html", doc: doc)
  end
end
```

#### Per-User Plugin Contexts

For applications where different users need different plugins (like multi-tenant systems), use **Contexts** for optimal performance:

```elixir
# Create user-specific contexts (typically at login or session start)
user1_context = Org.Parser.Context.new([Org.Plugins.Denote, Org.Plugins.CodeBlock])
user2_context = Org.Parser.Context.new([Org.Plugins.CodeBlock, Org.Plugins.DynamicBlock])

# Parse with user-specific plugins (very fast)
doc = Org.Parser.parse(content, context: user1_context)
doc2 = Org.Parser.parse(content2, context: user2_context)
```

**Context Benefits:**
- **No global state** - each user has isolated plugin configuration
- **Fast pattern matching** - pre-compiled patterns like registry
- **Memory efficient** - contexts can be cached per user session
- **Priority handling** - plugins automatically sorted by priority

#### When to Use Each Approach

**Use Contexts when:**
- Different users/tenants need different plugins
- You want registry-like performance without global state
- You're building multi-user applications
- Plugin sets change per request/session

**Use Registry when:**
- You have a single-user application  
- All users share the same plugin configuration
- You want the simplest setup

**Use Direct Plugins when:**
- You need different plugins for different parsing contexts
- You're in a script or one-off usage
- You want explicit control over which plugins run

#### Registry Management

```elixir
# Check what plugins are registered
Registry.list_plugins()

# Clear all plugins
Registry.clear()

# Check which plugins match specific content
Registry.get_plugins_for("[[denote:123][My Note]]")
```

#### Available Plugins

- **Denote** - Full support for [Denote](https://github.com/protesilaos/denote) note-taking system
  - Filename parsing: `@@ID==SIGNATURE--TITLE__KEYWORDS.EXT`
  - Denote links: `[[denote:ID][Description]]`
  - Query links: `[[denote:query-contents:REGEXP]]`
  - Dynamic blocks: `#+BEGIN: denote-backlinks`
  
- **CodeBlock** - Enhanced code block processing
- **DynamicBlock** - Support for dynamic content blocks

### Denote Integration Example

```elixir
# Parse a Denote filename
{:ok, components} = Org.Plugins.Denote.parse_filename(
  "20240115T144532--my-research-note__ai_ml_research.org"
)

# Generate a Denote filename
filename = Org.Plugins.Denote.generate_filename(
  "My New Note", 
  ["research", "elixir"], 
  DateTime.utc_now()
)

# Parse document with Denote links
content = """
#+TITLE: Research Notes
#+IDENTIFIER: 20240115T144532

See [[denote:20240116T093021][related work]] and
query for [[denote:query-contents:algorithm][algorithms]].
"""

doc = Org.Parser.parse(content)
```

## Example
You can see examples in [examples directory](./example)

## Roadmap
- [x] Document Structure
- [x] TODO keywords
- [x] Paragraphs
- [x] Tables
- [x] Code Blocks
- [x] Comments
- [x] Lists (ordered and unordered, with nesting)
- [x] Text Formatting
- [x] Links
- [x] JSON Export
- [x] Write mode
- [x] Parse Fragments
- [x] Tags
- [x] Custom TODO keywords
- [x] Workflow Sequences
- [x] Metadata and Properties
- [x] File property comments
- [x] Extended Timestamp support (write)
- [x] Repeater Intervals
- [x] Tag Inheritance (computed effective tags)
- [x] Enhanced Priority support
- [x] Property Drawer Management
- [x] Handling org-directories and multi file parsing
- [ ] Streaming of files
- [x] Denote Support
- [ ] Org Roam support
