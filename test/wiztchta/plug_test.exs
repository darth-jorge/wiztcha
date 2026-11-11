defmodule Wiztchta.PlugTest do
  use ExUnit.Case, async: true

  import Plug.Test

  defp call(params) do
    conn(:post, "/contact", params) |> Wiztchta.Plug.call(Wiztchta.Plug.init([]))
  end

  test "assigns :ok for a valid submission without halting" do
    challenge = Wiztchta.new(type: Wiztchta.Test.FixedChallenge)
    conn = call(%{"wiztchta" => %{"token" => challenge.token, "response" => "42"}})

    assert conn.assigns.wiztchta == :ok
    refute conn.halted
  end

  test "assigns the error for an invalid submission" do
    conn = call(%{"name" => "bot"})

    assert conn.assigns.wiztchta == {:error, :missing}
    refute conn.halted
  end
end
