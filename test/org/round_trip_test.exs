defmodule Org.RoundTripTest do
  use ExUnit.Case

  @cases [
    "* Project :work:\n** Subtask\n",
    "* Project :work:\n** Subtask :urgent:\n",
    "* Project\n** Subtask\n",
    "* A\n\nbody text\n\n* B\n",
    "* TODO [#A] Project :work:\nsome text\n** Subtask\n"
  ]

  describe "round-trip identity (load_string -> to_org_string)" do
    for {src, i} <- Enum.with_index(@cases) do
      @src src
      test "case #{i} round-trips unchanged: #{inspect(src)}" do
        assert @src == @src |> Org.load_string() |> Org.Writer.to_org_string()
      end
    end
  end

  describe "focused regressions" do
    test "Bug 1: inherited tags are NOT serialized onto children" do
      out = "* Project :work:\n** Subtask\n" |> Org.load_string() |> Org.Writer.to_org_string()
      refute out =~ "(work)"
      assert out =~ "** Subtask"
    end

    test "Bug 1: child keeps only its own direct tag" do
      out = "* Project :work:\n** Subtask :urgent:\n" |> Org.load_string() |> Org.Writer.to_org_string()
      refute out =~ "(work)"
      assert out =~ "** Subtask :urgent:"
    end

    test "Bug 2: trailing newline preserved" do
      out = "* Project\n** Subtask\n" |> Org.load_string() |> Org.Writer.to_org_string()
      assert String.ends_with?(out, "\n")
    end

    test "Bug 3: blank lines between blocks preserved" do
      src = "* A\n\nbody text\n\n* B\n"
      assert src == src |> Org.load_string() |> Org.Writer.to_org_string()
    end
  end
end
