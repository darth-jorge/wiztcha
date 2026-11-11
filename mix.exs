defmodule Wiztchta.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :wiztchta,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      package: package(),
      description: "Drop-in, pluggable CAPTCHA components for Phoenix forms and LiveViews.",
      docs: [main: "readme", extras: ["README.md"]]
    ]
  end

  def application do
    [
      mod: {Wiztchta.Application, []},
      extra_applications: [:logger, :crypto]
    ]
  end

  def cli do
    [preferred_envs: [precommit: :test]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix_live_view, "~> 1.1"},
      {:plug, "~> 1.16"},
      {:plug_crypto, "~> 2.0"},
      {:jason, "~> 1.2"},
      # Only for running the dev.exs demo app.
      {:bandit, "~> 1.5", only: :dev},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      files:
        ~w(lib priv/static/wiztchta.js package.json mix.exs README.md LICENSE .formatter.exs),
      links: %{}
    ]
  end

  defp aliases do
    [
      dev: "run --no-halt dev.exs",
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
