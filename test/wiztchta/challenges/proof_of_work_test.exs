defmodule Wiztchta.Challenges.ProofOfWorkTest do
  use ExUnit.Case, async: true

  alias Wiztchta.Challenges.ProofOfWork

  # Brute-forces the nonce the same way the browser does.
  defp solve(salt, difficulty) do
    Enum.find(Stream.map(0..10_000_000, &Integer.to_string/1), fn nonce ->
      match?(<<0::size(difficulty), _::bitstring>>, :crypto.hash(:sha256, salt <> nonce))
    end)
  end

  test "generate/1 exposes salt and difficulty" do
    {public, secret} = ProofOfWork.generate(difficulty: 10)
    assert %{"salt" => salt, "difficulty" => 10} = public
    assert byte_size(salt) == 32
    assert secret == {salt, 10}
  end

  test "valid?/3 accepts a correct nonce and rejects others" do
    {%{"salt" => salt}, secret} = ProofOfWork.generate(difficulty: 12)
    nonce = solve(salt, 12)

    assert ProofOfWork.valid?(secret, nonce, [])
    refute ProofOfWork.valid?({salt, 40}, nonce, [])
    refute ProofOfWork.valid?(secret, String.duplicate("1", 33), [])
    refute ProofOfWork.valid?(secret, nil, [])
  end

  test "round-trips through Wiztchta.verify/2" do
    challenge = Wiztchta.new(type: ProofOfWork, difficulty: 8)
    nonce = solve(challenge.public["salt"], 8)

    assert :ok =
             Wiztchta.verify(%{"wiztchta" => %{"token" => challenge.token, "response" => nonce}})
  end
end
