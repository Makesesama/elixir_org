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
    {:org, "~> 0.1.0"}
  ]
end
```

## Example
You can see an example in [examples directory](./example)

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
- [x] Metadata and Properties
- [x] File property comments
- [x] Handling org-directories and multi file parsing
- [ ] Streaming of files
- [ ] Denote Support
- [ ] Org Roam support
- [ ] Something like org-ql
