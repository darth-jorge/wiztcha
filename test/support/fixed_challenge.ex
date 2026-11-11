defmodule Wiztchta.Test.FixedChallenge do
  @moduledoc false
  # Deterministic challenge type: the answer is always "42".
  @behaviour Wiztchta.Challenge
  use Phoenix.Component

  @impl true
  def generate(_opts), do: {%{"question" => "life?"}, "42"}

  @impl true
  def valid?(answer, response, _opts), do: answer == response

  @impl true
  def render(assigns) do
    ~H"""
    <input type="text" id={@id <> "-response"} name={@name <> "[response]"} />
    """
  end
end
