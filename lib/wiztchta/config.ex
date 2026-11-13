defmodule Wiztchta.Config do
  @moduledoc false

  @defaults [
    default_challenge: Wiztchta.Challenges.ProofOfWork,
    max_age: 300,
    store: Wiztchta.Store.ETS,
    param: "wiztchta",
    honeypot: true,
    honeypot_field: "website",
    min_time: 2
  ]

  @doc "Reads `key` from per-call opts, then app env, then defaults."
  def get(key, opts \\ []) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> value
      :error -> Application.get_env(:wiztchta, key, Keyword.get(@defaults, key))
    end
  end

  def secret_key_base!(opts) do
    endpoint = get(:endpoint, opts)
    secret = get(:secret_key_base, opts) || (endpoint && endpoint.config(:secret_key_base))

    secret ||
      raise ArgumentError, """
      Wiztchta needs a secret to encrypt challenges. Configure one of:

          config :wiztchta, endpoint: MyAppWeb.Endpoint
          config :wiztchta, secret_key_base: "at least 64 random bytes"
      """
  end
end
