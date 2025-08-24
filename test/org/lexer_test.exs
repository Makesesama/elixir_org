defmodule Org.LexerTest do
  use ExUnit.Case
  doctest Org.Lexer

  require OrgTestHelper

  describe "lex document" do
    setup do
      tokens = Org.Lexer.lex(OrgTest.example_document())
      {:ok, %{tokens: tokens}}
    end

    OrgTestHelper.test_tokens([
      {:comment, "+TITLE: Hello World"},
      {:empty_line},
      {:section_title, 1, "Hello", nil, nil},
      {:section_title, 2, "World", nil, nil},
      {:table_row, ["X", "Y"]},
      {:table_row, ["---+---"]},
      {:table_row, ["0", "4"]},
      {:table_row, ["1", "7"]},
      {:table_row, ["2", "5"]},
      {:table_row, ["3", "6"]},
      {:section_title, 2, "Universe", nil, nil},
      {:text, "Something something..."},
      {:section_title, 1, "Also", nil, nil},
      {:text, "1"},
      {:section_title, 2, "another", nil, nil},
      {:text, "2"},
      {:section_title, 3, "thing", nil, nil},
      {:text, "3"},
      {:section_title, 4, "is nesting", nil, nil},
      {:text, "4"},
      {:section_title, 5, "stuff", nil, nil},
      {:text, "5"},
      {:section_title, 2, "at", nil, nil},
      {:text, "6"},
      {:section_title, 3, "different", nil, nil},
      {:text, "7"},
      {:section_title, 4, "levels", nil, nil},
      {:text, "8"},
      {:section_title, 3, "and", nil, nil},
      {:text, "9"},
      {:section_title, 3, "next", nil, nil},
      {:text, "10"},
      {:section_title, 3, "to", nil, nil},
      {:text, "11"},
      {:section_title, 3, "one", nil, nil},
      {:text, "12"},
      {:section_title, 3, "another", nil, nil},
      {:text, "13"},
      {:begin_src, "sql", ""},
      {:raw_line, "SELECT * FROM products;"},
      {:end_src},
      {:empty_line}
    ])
  end
end
