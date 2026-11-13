defmodule Wiztchta.Honeypot do
  @moduledoc """
  A hidden trap field rendered by `Wiztchta.Components.wiztchta/1`.

  People never see the field, so they leave it empty. Naive bots fill in
  every input they find, so a non-empty value marks the submission as
  automated and `Wiztchta.verify/2` returns `{:error, :honeypot}`.

  The field is a normal text input moved off-screen (bots skip
  `type="hidden"`), with `aria-hidden`, `tabindex="-1"` and
  `autocomplete="off"` so screen readers, keyboard users and browser
  autofill don't trip it.

  ## Options

    * `:honeypot` - set to `false` to disable. Defaults to `true`.
    * `:honeypot_field` - the field's param name, nested under the `:param`
      key (`wiztchta[website]` by default). Pick something bots like to
      fill but browsers rarely autofill.

  ## Handling a caught bot

  Consider responding as if the submission succeeded and discarding it,
  instead of showing an error that tells the bot what it did wrong.
  """

  alias Wiztchta.Config

  @reserved ~w(token response)

  @doc "Whether the honeypot is enabled."
  @spec enabled?(keyword) :: boolean
  def enabled?(opts \\ []), do: Config.get(:honeypot, opts) != false

  @doc "The honeypot field name (without the `:param` prefix)."
  @spec field(keyword) :: String.t()
  def field(opts \\ []) do
    case Config.get(:honeypot_field, opts) do
      field when field in @reserved ->
        raise ArgumentError, ":honeypot_field cannot be #{inspect(field)}, Wiztchta uses it"

      field when is_binary(field) and field != "" ->
        field

      other ->
        raise ArgumentError, ":honeypot_field must be a non-empty string, got: #{inspect(other)}"
    end
  end

  @doc """
  Checks the submitted Wiztchta fields (the map under the `:param` key).

  A missing field counts as empty, so forms rendered before the honeypot
  was enabled keep working.
  """
  @spec check(map, keyword) :: :ok | {:error, :honeypot}
  def check(fields, opts \\ []) do
    if enabled?(opts) and filled?(Map.get(fields, field(opts))),
      do: {:error, :honeypot},
      else: :ok
  end

  defp filled?(nil), do: false
  defp filled?(value) when is_binary(value), do: String.trim(value) != ""
  # Our form only ever sends a string; anything else was crafted by hand.
  defp filled?(_value), do: true
end
