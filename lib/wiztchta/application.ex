defmodule Wiztchta.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [Wiztchta.Store.ETS]
    Supervisor.start_link(children, strategy: :one_for_one, name: Wiztchta.Supervisor)
  end
end
