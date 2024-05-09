defmodule Crawldis.MixProject do
  use Mix.Project

  def project do
    [
      app: :crawldis,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock"
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]


  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Crawldis.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:broadway, "~> 1.0"},
      {:libcluster, "~> 3.3"},
      {:horde, "~> 0.8"},
      {:delta_crdt, "~> 0.6.3"},
      {:exsync, "~> 0.2", only: :dev},
      {:uuid, "~> 1.1" },
      {:hardhat, "~> 1.0.0"},
      {:telemetry, "~> 1.0"},
      {:phoenix_client, "~> 0.3"},
      {:typed_struct, "~> 0.3.0"},
      {:mimic, "~> 1.7", only: :test},
      {:meeseeks, "~> 0.17.0"},
      {:jason, "~> 1.4"},
      {:params, "~> 2.0"},
      {:ecto_sql, "~> 3.11"},
      {:flame, "~> 0.1.12"}
    ]
  end

  defp aliases do
    [
      setup: "cmd echo pass"
    ]
  end
end
