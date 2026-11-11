defmodule Wiztchta.Challenges.ProofOfWork do
  @moduledoc """
  Invisible proof-of-work challenge (the default).

  The browser must find a `nonce` such that `SHA-256(salt <> nonce)` starts
  with `difficulty` zero bits. Legitimate users wait about a second; bots
  pay that CPU cost on every submission. The server verifies with one hash.

  Requires the `wiztchta` JS (see the README) and a secure context
  (HTTPS or localhost), since it uses `crypto.subtle`.

  ## Options

    * `:difficulty` - leading zero bits required. Each +1 doubles the
      average work. Defaults to the `:pow_difficulty` config, or `16`.
  """

  @behaviour Wiztchta.Challenge
  use Phoenix.Component

  @default_difficulty 16
  @max_nonce_size 32

  @impl true
  def generate(opts) do
    difficulty = Wiztchta.Config.get(:pow_difficulty, opts) || @default_difficulty
    difficulty = Keyword.get(opts, :difficulty, difficulty)
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
      <%!-- Managed by the JS solver; ignored so LiveView patches don't wipe the answer. --%>
      <div id={@id <> "-pow-state"} phx-update="ignore" data-state="pending">
        <input type="hidden" id={@id <> "-response"} name={@name <> "[response]"} value="" />
        <span class="wiztchta-status" data-wiztchta-status aria-live="polite">
          Verifying you are human…
        </span>
      </div>
      <noscript>Please enable JavaScript to complete the verification.</noscript>
    </div>
    """
  end
end
