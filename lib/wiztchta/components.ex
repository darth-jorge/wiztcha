defmodule Wiztchta.Components do
  @moduledoc """
  Function components for rendering challenges inside forms.

  Import them app-wide, e.g. in the `html_helpers` of `my_app_web.ex`:

      import Wiztchta.Components
  """

  use Phoenix.Component

  @doc """
  Renders a challenge plus the hidden token input. Place it inside any form.

  In controllers/dead views a fresh challenge is generated on every render:

      <.form for={@form} action={~p"/contact"}>
        ...
        <.wiztchta />
      </.form>

  In LiveViews, keep the challenge in an assign so re-renders don't replace
  it, and assign a new one after each submit:

      socket = assign(socket, :challenge, Wiztchta.new())

      <.wiztchta challenge={@challenge} />
  """
  attr :challenge, Wiztchta.Challenge,
    default: nil,
    doc: "a challenge from `Wiztchta.new/1`; generated on render when nil"

  attr :type, :atom, default: nil, doc: "challenge module, when generating on render"
  attr :opts, :list, default: [], doc: "options for `Wiztchta.new/1`, when generating on render"
  attr :id, :string, default: "wiztchta", doc: "DOM id; must be unique per page"
  attr :name, :string, default: nil, doc: "form param name; defaults to the `:param` config"
  attr :class, :any, default: nil
  attr :rest, :global

  def wiztchta(assigns) do
    challenge =
      assigns.challenge ||
        Wiztchta.new(Keyword.put_new(assigns.opts, :type, assigns.type))

    assigns =
      assigns
      |> assign(:challenge, challenge)
      |> assign(:name, assigns.name || Wiztchta.Config.get(:param, assigns.opts))

    ~H"""
    <div id={@id} class={["wiztchta", @class]} {@rest}>
      <input type="hidden" id={@id <> "-token"} name={@name <> "[token]"} value={@challenge.token} />
      <.challenge_ui challenge={@challenge} id={@id} name={@name} />
    </div>
    """
  end

  defp challenge_ui(assigns), do: assigns.challenge.type.render(assigns)
end
