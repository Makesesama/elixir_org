defmodule Org.Mixfile do
  use Mix.Project

  def project do
    [
      app: :org,
      version: "0.1.1",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      description: "org-mode parser",
      source_url: "https://github.com/Makesesama/elixir_org",
      docs: [
        main: "Org",
        extras: ["README.md"]
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:ex_unit]
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Makesesama"],
      links: %{
        "GitHub" => "https://github.com/Makesesama/elixir_org"
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
