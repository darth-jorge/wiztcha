defmodule Wiztchta.Challenges.Math do
  @moduledoc """
  Simple arithmetic question ("What is 3 + 4?"). Works without JavaScript.

  Weaker against targeted bots than `Wiztchta.Challenges.ProofOfWork`, but
  useful as a no-JS fallback or for low-risk forms.
  """

  @behaviour Wiztchta.Challenge
  use Phoenix.Component

  @impl true
  def generate(_opts) do
    a = Enum.random(1..9)
    b = Enum.random(1..9)

    {question, answer} =
      case Enum.random([:+, :-, :*]) do
        :+ -> {"#{a} + #{b}", a + b}
        :- -> {"#{max(a, b)} - #{min(a, b)}", abs(a - b)}
        :* -> {"#{a} × #{b}", a * b}
      end

    {%{"question" => question}, answer}
  end

  @impl true
  def valid?(answer, response, _opts) when is_binary(response) do
    Integer.parse(String.trim(response)) == {answer, ""}
  end

  def valid?(_answer, _response, _opts), do: false

  @impl true
  def render(assigns) do
    ~H"""
    <div class="wiztchta-math">
      <label for={@id <> "-response"} class="wiztchta-label">
        What is {@challenge.public["question"]}?
      </label>
      <input
        type="text"
        id={@id <> "-response"}
        name={@name <> "[response]"}
        class="wiztchta-input"
        inputmode="numeric"
        autocomplete="off"
        required
      />
    </div>
    """
  end
end
