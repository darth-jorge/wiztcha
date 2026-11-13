defmodule Wiztchta.Challenges.ProofOfWork do
  @moduledoc """
  Invisible proof-of-work challenge (the default).

  The browser must find a `nonce` such that `SHA-256(salt <> nonce)` starts
  with `difficulty` zero bits. Solving starts as soon as the form renders,
  so it usually finishes while the person is still typing; the form can't be
  submitted until it does. The server verifies with one hash.

  Requires the `wiztchta` JS (see the README) and a secure context
  (HTTPS or localhost), since it uses `crypto.subtle`.

  ## Options

    * `:difficulty` - leading zero bits required, from 1 to 32. Each +1
      doubles the average work. Defaults to the `:pow_difficulty` config, or
      `16`. Raise it (e.g. to 18) on long forms, where solving finishes
      before the person does anyway; keep it low on quick forms.
  """

  @behaviour Wiztchta.Challenge
  use Phoenix.Component

  @default_difficulty 16
  @max_nonce_size 32

  @impl true
  def generate(opts) do
    difficulty = Wiztchta.Config.get(:pow_difficulty, opts) || @default_difficulty
    difficulty = opts |> Keyword.get(:difficulty, difficulty) |> validate_difficulty!()
    salt = Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)

    {%{"salt" => salt, "difficulty" => difficulty}, {salt, difficulty}}
  end

  @impl true
  def valid?({salt, difficulty}, nonce, _opts)
      when is_binary(nonce) and byte_size(nonce) <= @max_nonce_size do
    hash = :crypto.hash(:sha256, salt <> nonce)
    match?(<<0::size(difficulty), _::bitstring>>, hash)
  end

  def valid?(_secret, _nonce, _opts), do: false

  # A typo such as 160 would make browsers spin forever; fail at render instead.
  defp validate_difficulty!(difficulty) when difficulty in 1..32, do: difficulty

  defp validate_difficulty!(other) do
    raise ArgumentError,
          ":difficulty must be an integer from 1 to 32, got: #{inspect(other)}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id <> "-pow"}
      class="wiztchta-pow"
      phx-hook="WiztchtaProofOfWork"
      data-wiztchta-pow
      data-salt={@challenge.public["salt"]}
      data-difficulty={@challenge.public["difficulty"]}
    >
      <%!--
        Owned by the JS solver. The container is ignored so patches keep the
        answer; data-state sits on a child because LiveView still syncs the
        data-* attributes of an ignored container itself with the server.
      --%>
      <div id={@id <> "-pow-state"} phx-update="ignore">
        <div class="wiztchta-pow-box" data-state="pending">
          <input type="hidden" id={@id <> "-response"} name={@name <> "[response]"} value="" />
          <span class="wiztchta-status" data-wiztchta-status aria-live="polite">
            Verifying you are human…
          </span>
        </div>
      </div>
      <noscript>Please enable JavaScript to complete the verification.</noscript>
    </div>
    """
  end
end
