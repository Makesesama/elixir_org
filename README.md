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

## Roadmap
- [x] Document Structure
- [x] TODO keywords
- [x] Paragraphs
- [x] Tables
- [x] Code Blocks
- [x] Comments
- [ ] Custom TODO keywords
- [ ] Tags
- [ ] Links
- [ ] Text Formatting
- [ ] Lists
- [ ] Metadata and Properties
- [ ] Export Formats
- [ ] Streaming of files
