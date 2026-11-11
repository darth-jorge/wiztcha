defmodule Wiztchta.Store.ETSTest do
  use ExUnit.Case, async: true

  alias Wiztchta.Store.ETS

  defp unique_id, do: "test-" <> Integer.to_string(System.unique_integer([:positive]))

  test "consume/3 succeeds once per id" do
    id = unique_id()
    expires_at = System.system_time(:second) + 60

    assert :ok = ETS.consume(id, expires_at)
    assert {:error, :already_used} = ETS.consume(id, expires_at)
  end

  test "sweep/1 forgets expired ids only" do
    now = System.system_time(:second)
    expired = unique_id()
    live = unique_id()

    :ok = ETS.consume(expired, now - 1)
    :ok = ETS.consume(live, now + 60)
    ETS.sweep(now)

    assert :ok = ETS.consume(expired, now + 60)
    assert {:error, :already_used} = ETS.consume(live, now + 60)
  end
end
