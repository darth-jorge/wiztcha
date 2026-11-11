defmodule Wiztchta.Store do
  @moduledoc """
  Behaviour for replay protection: remembers which challenge tokens were
  already submitted until they expire.

  The default, `Wiztchta.Store.ETS`, is started automatically and keeps
  used ids in memory on the local node. In a multi-node cluster a token could
  be replayed once per node; plug in a shared store (Redis, Nebulex, a
  database...) to prevent that:

      config :wiztchta, store: MyApp.WiztchtaRedisStore

  Set `store: nil` to disable replay protection.
  """

  @doc """
  Atomically marks `id` as used until `expires_at` (unix seconds).

  Must return `{:error, :already_used}` if `id` was already consumed.
  """
  @callback consume(id :: String.t(), expires_at :: integer, opts :: keyword) ::
              :ok | {:error, :already_used}
end
