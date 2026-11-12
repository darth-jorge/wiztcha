defmodule WiztchtaTest do
  use ExUnit.Case, async: true

  alias Wiztchta.Test.FixedChallenge

  defp submit(challenge, response, param \\ "wiztchta") do
    %{param => %{"token" => challenge.token, "response" => response}}
  end

  describe "new/1" do
    test "builds a challenge of the requested type with an opaque token" do
      challenge = Wiztchta.new(type: FixedChallenge)

      assert %Wiztchta.Challenge{type: FixedChallenge, public: %{"question" => "life?"}} =
               challenge

      # The secret's encoded term must not appear anywhere in the decoded token.
      decoded =
        challenge.token
        |> String.split(".")
        |> Enum.map_join(&Base.url_decode64!(&1, padding: false))

      "42" |> :erlang.term_to_binary() |> binary_part(1, 7) |> then(&refute(decoded =~ &1))
    end

    test "defaults to proof of work" do
      assert %Wiztchta.Challenge{type: Wiztchta.Challenges.ProofOfWork} = Wiztchta.new()
    end

    test "raises without a secret" do
      assert_raise ArgumentError, ~r/needs a secret/, fn ->
        Wiztchta.new(type: FixedChallenge, secret_key_base: nil, endpoint: nil)
      end
    end
  end

  describe "verify/2" do
    test "accepts a correct response" do
      assert :ok = Wiztchta.verify(submit(Wiztchta.new(type: FixedChallenge), "42"))
    end

    test "accepts the inner params map" do
      challenge = Wiztchta.new(type: FixedChallenge)
      assert :ok = Wiztchta.verify(%{"token" => challenge.token, "response" => "42"})
    end

    test "honours a custom param name" do
      challenge = Wiztchta.new(type: FixedChallenge)
      assert :ok = Wiztchta.verify(submit(challenge, "42", "captcha"), param: "captcha")
    end

    test "rejects a wrong response" do
      challenge = Wiztchta.new(type: FixedChallenge)
      assert {:error, :wrong_answer} = Wiztchta.verify(submit(challenge, "41"))
    end

    test "rejects replays, including retries after a wrong answer" do
      challenge = Wiztchta.new(type: FixedChallenge)
      assert {:error, :wrong_answer} = Wiztchta.verify(submit(challenge, "41"))
      assert {:error, :already_used} = Wiztchta.verify(submit(challenge, "42"))
    end

    test "allows replays when the store is disabled" do
      challenge = Wiztchta.new(type: FixedChallenge)
      assert :ok = Wiztchta.verify(submit(challenge, "42"), store: nil)
      assert :ok = Wiztchta.verify(submit(challenge, "42"), store: nil)
    end

    test "rejects expired challenges" do
      challenge = Wiztchta.new(type: FixedChallenge, max_age: 0)
      assert {:error, :expired} = Wiztchta.verify(submit(challenge, "42"))
    end

    test "rejects tampered or foreign tokens" do
      challenge = Wiztchta.new(type: FixedChallenge)
      params = submit(%{challenge | token: challenge.token <> "x"}, "42")
      assert {:error, :invalid_token} = Wiztchta.verify(params)

      assert {:error, :invalid_token} =
               Wiztchta.verify(submit(challenge, "42"),
                 secret_key_base: String.duplicate("x", 64)
               )
    end

    test "reports missing input" do
      challenge = Wiztchta.new(type: FixedChallenge)
      assert {:error, :missing} = Wiztchta.verify(%{})
      assert {:error, :missing} = Wiztchta.verify(%{"wiztchta" => "nope"})
      assert {:error, :missing} = Wiztchta.verify(submit(challenge, ""))
      assert {:error, :missing} = Wiztchta.verify(nil)
    end
  end

  describe "verify/2 honeypot" do
    defp with_honeypot(params, value), do: put_in(params, ["wiztchta", "website"], value)

    test "rejects a filled honeypot even with a correct answer" do
      params = submit(Wiztchta.new(type: FixedChallenge), "42") |> with_honeypot("spam")
      assert {:error, :honeypot} = Wiztchta.verify(params)
    end

    test "checks the honeypot before consuming the token" do
      challenge = Wiztchta.new(type: FixedChallenge)
      assert {:error, :honeypot} = Wiztchta.verify(submit(challenge, "42") |> with_honeypot("x"))
      assert :ok = Wiztchta.verify(submit(challenge, "42"))
    end

    test "accepts an empty honeypot, and forms rendered without one" do
      params = submit(Wiztchta.new(type: FixedChallenge), "42") |> with_honeypot("")
      assert :ok = Wiztchta.verify(params)
      assert :ok = Wiztchta.verify(submit(Wiztchta.new(type: FixedChallenge), "42"))
    end

    test "can be disabled per call" do
      params = submit(Wiztchta.new(type: FixedChallenge), "42") |> with_honeypot("x")
      assert :ok = Wiztchta.verify(params, honeypot: false)
    end
  end

  test "error_message/1 covers every error" do
    for reason <- [:missing, :honeypot, :invalid_token, :expired, :already_used, :wrong_answer] do
      assert is_binary(Wiztchta.error_message(reason))
    end
  end
end
