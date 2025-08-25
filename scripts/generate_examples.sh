#!/usr/bin/env bash

# Generate comprehensive examples for Elixir Org Parser
# This script runs the Elixir example generator and shows the results

set -e  # Exit on any error

echo "🚀 Elixir Org Parser - Example Generator"
echo "========================================"

# Check if we're in the right directory
if [[ ! -f "mix.exs" ]]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Compile the project first
echo "📦 Compiling project..."
mix compile

# Generate examples
echo "📝 Generating examples..."
mix run scripts/generate_examples.exs

# Show what was generated
echo ""
echo "📂 Generated files:"
find example -name "README.md" -o -name "*.org" -o -name "*.json" | grep -v org_to_html | sort | while read -r file; do
    size=$(du -h "$file" | cut -f1)
    echo "  - $file ($size)"
done

echo ""
echo "🎯 Quick Start Guide:"
echo "  1. View examples: ls example/"
echo "  2. Read basic parsing: cat example/basic_parsing/README.md"
echo "  3. See JSON output: head example/json_serialization/sample_data.json"
echo "  4. Check generated org: cat example/comprehensive_workflow/complete_project.org"

echo ""
echo "✨ You can also run individual examples:"
echo "  - Basic write demo: mix run example/write_operations/example.exs"
echo "  - JSON export: mix run example/json_serialization/export_example.exs"

echo ""
echo "✅ Example generation complete!"