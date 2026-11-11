defmodule Wiztchta.Token do
  @moduledoc false
  # Challenges are encrypted (not just signed) so answers such as the
  # result of a math question are never visible to the browser.

  alias Wiztchta.Config

  @salt "wiztchta challenge"

  def encrypt(payload, max_age, opts) do
    Plug.Crypto.encrypt(Config.secret_key_base!(opts), @salt, payload, max_age: max_age)
  end

  def decrypt(token, opts) do
    case Plug.Crypto.decrypt(Config.secret_key_base!(opts), @salt, token) do
      {:ok, %{id: _, type: type, secret: _, expires_at: _} = payload} when is_atom(type) ->
        {:ok, payload}

      {:error, :expired} ->
        {:error, :expired}

      _ ->
        {:error, :invalid_token}
    end
  end
end
