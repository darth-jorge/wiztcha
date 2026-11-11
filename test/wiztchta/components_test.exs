defmodule Wiztchta.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Wiztchta.Challenges.{Math, ProofOfWork}

  defp render_doc(assigns) do
    (&Wiztchta.Components.wiztchta/1)
    |> render_component(assigns)
    |> LazyHTML.from_fragment()
  end

  defp attr(doc, selector, name) do
    doc |> LazyHTML.query(selector) |> LazyHTML.attribute(name) |> List.first()
  end

  defp count(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.count()

  test "renders the given challenge's token and proof-of-work UI" do
    challenge = Wiztchta.new(type: ProofOfWork, difficulty: 9)
    doc = render_doc(challenge: challenge)

    assert attr(doc, "#wiztchta-token", "value") == challenge.token
    assert attr(doc, "#wiztchta-token", "name") == "wiztchta[token]"
    assert attr(doc, "#wiztchta-pow", "phx-hook") == "WiztchtaProofOfWork"
    assert attr(doc, "#wiztchta-pow", "data-salt") == challenge.public["salt"]
    assert attr(doc, "#wiztchta-pow", "data-difficulty") == "9"
    assert attr(doc, "#wiztchta-pow-state", "phx-update") == "ignore"
    assert attr(doc, "#wiztchta-response", "name") == "wiztchta[response]"
  end

  test "generates a challenge of the requested type when none is given" do
    doc = render_doc(type: Math, id: "contact-captcha", name: "captcha")

    assert count(doc, "#contact-captcha-token[name='captcha[token]']") == 1
    assert count(doc, "#contact-captcha .wiztchta-math") == 1
    assert count(doc, "#contact-captcha-response[name='captcha[response]']") == 1
  end

  test "rendered token verifies" do
    doc = render_doc(type: Wiztchta.Test.FixedChallenge)
    token = attr(doc, "#wiztchta-token", "value")

    assert :ok = Wiztchta.verify(%{"token" => token, "response" => "42"})
  end
end
