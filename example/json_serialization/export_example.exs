#!/usr/bin/env elixir

# Example: Export org-mode document to JSON
# Usage: elixir json_export.exs [input.org] [output.json]

defmodule JSONExporter do
  def main(args \\ []) do
    {input_file, output_file} = parse_args(args)

    IO.puts("Converting #{input_file} to JSON...")

    # Read and parse the org file
    doc = Org.load_file(input_file)

    # Convert to JSON-encodable map
    json_map = Org.to_json_map(doc)

    # Encode to JSON string
    json_string = encode_json(json_map)

    # Write to file
    File.write!(output_file, json_string)

    IO.puts("Successfully wrote JSON to #{output_file}")
    IO.puts("\nSample of the JSON structure:")
    IO.puts(json_string |> String.slice(0..500))
    IO.puts("...")
  end

  defp parse_args([input, output]), do: {input, output}
  defp parse_args([input]), do: {input, Path.rootname(input) <> ".json"}

  defp parse_args([]) do
    # Use the sample.org file as default
    {"example/org_to_html/sample.org", "example/sample.json"}
  end

  defp encode_json(data) do
    # Try to use :json module if available (OTP 27+)
    # Otherwise fall back to inspect with pretty printing
    if Code.ensure_loaded?(:json) do
      case :json.encode(data) do
        {:ok, json} -> json
        _ -> inspect(data, pretty: true, limit: :infinity)
      end
    else
      # For older Elixir versions, use inspect as a fallback
      # In production, you'd want to use Jason or Poison library
      inspect(data, pretty: true, limit: :infinity)
    end
  end
end

# Run the exporter
JSONExporter.main(System.argv())
