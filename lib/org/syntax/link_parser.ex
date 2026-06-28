defmodule Org.Syntax.LinkParser do
  @moduledoc """
  NimbleParsec-backed parser for bounded Org links.

  Supports the currently implemented link subset:
  - described links: `[[url][description]]`
  - simple links: `[[url]]`
  - bare `http://` and `https://` URLs
  """

  import NimbleParsec

  link_text = utf8_string([not: ?[, not: ?], not: ?\n], min: 1)

  described_link =
    ignore(string("[["))
    |> unwrap_and_tag(link_text, :url)
    |> ignore(string("]["))
    |> unwrap_and_tag(link_text, :description)
    |> ignore(string("]]"))
    |> tag(:described)

  simple_link =
    ignore(string("[["))
    |> unwrap_and_tag(link_text, :url)
    |> ignore(string("]]"))
    |> tag(:simple)

  bare_url =
    choice([string("https://"), string("http://")])
    |> utf8_string([not: ?\s, not: ?[, not: ?], not: ?\n], min: 1)
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:url)
    |> tag(:bare)

  defparsec(:link_prefix, choice([described_link, simple_link, bare_url]))

  @type parsed_link :: %{url: String.t(), description: String.t() | nil, raw: String.t()}

  @spec parse_prefix(String.t()) :: {:ok, parsed_link(), String.t()} | :error
  def parse_prefix(text) when is_binary(text) do
    case link_prefix(text) do
      {:ok, [{kind, fields}], rest, _context, _line, _offset} ->
        raw_length = byte_size(text) - byte_size(rest)
        {:ok, build_link(kind, fields, binary_part(text, 0, raw_length)), rest}

      _ ->
        :error
    end
  end

  def parse_prefix(_), do: :error

  @spec extract_links(String.t()) :: list(parsed_link())
  def extract_links(text) when is_binary(text), do: do_extract_links(text, [])
  def extract_links(_), do: []

  defp do_extract_links("", acc), do: Enum.reverse(acc)

  defp do_extract_links(text, acc) do
    case parse_prefix(text) do
      {:ok, link, rest} ->
        do_extract_links(rest, [link | acc])

      :error ->
        case next_codepoint_rest(text) do
          "" -> Enum.reverse(acc)
          rest -> do_extract_links(rest, acc)
        end
    end
  end

  defp build_link(:described, fields, raw) do
    %{url: fields[:url], description: fields[:description], raw: raw}
  end

  defp build_link(:simple, fields, raw) do
    %{url: fields[:url], description: nil, raw: raw}
  end

  defp build_link(:bare, fields, raw) do
    %{url: fields[:url], description: nil, raw: raw}
  end

  defp next_codepoint_rest(<<_::utf8, rest::binary>>), do: rest
  defp next_codepoint_rest(<<_, rest::binary>>), do: rest
end
