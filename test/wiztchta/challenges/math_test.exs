defmodule Wiztchta.Challenges.MathTest do
  use ExUnit.Case, async: true

  alias Wiztchta.Challenges.Math

  test "the secret answers the public question" do
    for _ <- 1..50 do
      {%{"question" => question}, answer} = Math.generate([])
      [a, op, b] = String.split(question, " ")
      {a, b} = {String.to_integer(a), String.to_integer(b)}

      expected =
        case op do
          "+" -> a + b
          "-" -> a - b
          "×" -> a * b
        end

      assert answer == expected
      assert answer >= 0
    end
  end

  test "valid?/3 tolerates whitespace but nothing else" do
    assert Math.valid?(7, " 7 ", [])
    refute Math.valid?(7, "7.0", [])
    refute Math.valid?(7, "8", [])
    refute Math.valid?(7, nil, [])
  end
end
