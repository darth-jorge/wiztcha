defmodule Wiztchta.Store.ETS do
  @moduledoc """
  Default in-memory `Wiztchta.Store`, local to each node.

  Started by the `:wiztchta` application. Expired ids are swept every minute.
  """

  @behaviour Wiztchta.Store
  use GenServer

  @table :wiztchta_used_tokens
  @sweep_interval :timer.minutes(1)

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl Wiztchta.Store
  def consume(id, expires_at, _opts \\ []) do
    if :ets.insert_new(@table, {id, expires_at}), do: :ok, else: {:error, :already_used}
  end

  @doc false
  def sweep(now \\ System.system_time(:second)) do
    :ets.select_delete(@table, [{{:_, :"$1"}, [{:<, :"$1", now}], [true]}])
  end

  @impl GenServer
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, write_concurrency: true])
    schedule_sweep()
    {:ok, nil}
  end

  @impl GenServer
  def handle_info(:sweep, state) do
    sweep()
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval)
end
