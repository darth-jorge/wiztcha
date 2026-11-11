defmodule Wiztchta.Plug do
  @moduledoc """
  Verifies the submitted challenge and stores the result in
  `conn.assigns.wiztchta` as `:ok` or `{:error, reason}`.

  The plug never halts; your action decides what to do:

      plug Wiztchta.Plug when action in [:create]

      def create(conn, params) do
        case conn.assigns.wiztchta do
          :ok -> ...
          {:error, reason} ->
            conn
            |> put_flash(:error, Wiztchta.error_message(reason))
            |> render(:new, ...)
        end
      end

  Options are forwarded to `Wiztchta.verify/2`.
  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    Plug.Conn.assign(conn, :wiztchta, Wiztchta.verify(conn.params, opts))
  end
end
