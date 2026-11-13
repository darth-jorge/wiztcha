defmodule Wiztchta.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/darth-jorge/wiztchta"

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
      source_url: @source_url,
      docs: [
        main: "readme",
        source_ref: "v#{@version}",
        extras: ["README.md", "CHANGELOG.md", "LICENSE"]
      ]
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
      # Only for running the dev.exs demo app.
      {:jason, "~> 1.2", only: [:dev, :test]},
      {:bandit, "~> 1.5", only: :dev},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      files:
        ~w(lib priv/static/wiztchta.js package.json mix.exs README.md CHANGELOG.md LICENSE .formatter.exs),
      links: %{"GitHub" => @source_url, "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"}
    ]
  end

  defp aliases do
    [
      dev: "run --no-halt dev.exs",
      "test.js": "cmd node --test test/js/",
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format",
        "test",
        "test.js"
      ]
    ]
  end
end
