defmodule Wiztchta.HoneypotTest do
  use ExUnit.Case, async: true

  alias Wiztchta.Honeypot

  describe "check/2" do
    test "passes when the field is empty, blank or missing" do
      assert :ok = Honeypot.check(%{"website" => ""})
      assert :ok = Honeypot.check(%{"website" => "  "})
      assert :ok = Honeypot.check(%{})
    end

    test "trips when the field is filled" do
      assert {:error, :honeypot} = Honeypot.check(%{"website" => "http://spam.example"})
    end

    test "trips on non-string values, which our form never sends" do
      assert {:error, :honeypot} = Honeypot.check(%{"website" => ["x"]})
      assert {:error, :honeypot} = Honeypot.check(%{"website" => %{"a" => "b"}})
    end

    test "uses the configured field name" do
      assert :ok = Honeypot.check(%{"website" => "x"}, honeypot_field: "url")
      assert {:error, :honeypot} = Honeypot.check(%{"url" => "x"}, honeypot_field: "url")
    end

    test "does nothing when disabled" do
      assert :ok = Honeypot.check(%{"website" => "x"}, honeypot: false)
    end
  end

  describe "field/1" do
    test "defaults to website" do
      assert Honeypot.field() == "website"
    end

    test "rejects names Wiztchta already uses, and empty names" do
      for bad <- ["token", "response", "", nil] do
        assert_raise ArgumentError, fn -> Honeypot.field(honeypot_field: bad) end
      end
    end
  end
end
