defmodule Params.Mixfile do
  use Mix.Project

  @version "2.2.0"

  @deps [
    {:ecto, "~> 2.0 or ~> 3.12.0"},
    {:ecto_sql, "~> 3.12.0"},
    {:ex_doc, "~> 0.19", only: :dev, runtime: false},
    {:earmark, ">= 0.0.0", only: :dev, runtime: false},
    {:dialyxir, "~> 0.5", only: :dev, runtime: false},
    {:mix_test_interactive, "~> 1.0", only: [:dev], runtime: false},
    {:recode, "~> 0.4", only: :dev}
  ]

  def project do
    [
      app: :params,
      version: @version,
      elixir: "~> 1.2",
      name: "Params",
      source_url: github(),
      homepage_url: "https://hex.pm/packages/params",
      docs: docs(),
      description: description(),
      package: package(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: @deps,
      dialyzer: [plt_add_apps: [:ecto]]
    ]
  end

  def description do
    """
    Parameter structure validation and casting with Ecto.Schema.
    """
  end

  def github do
    "https://github.com/vic/params"
  end

  def package do
    [
      files: ~w(lib mix.exs README* LICENSE),
      maintainers: ["Victor Hugo Borja <vborja@apache.org>"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => github()
      }
    ]
  end

  def docs do
    [
      extras: ["README.md"]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end
end
