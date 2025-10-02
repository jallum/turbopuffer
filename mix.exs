defmodule Turbopuffer.MixProject do
  use Mix.Project

  def project do
    [
      app: :turbopuffer,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Elixir client for the Turbopuffer vector search API",
      package: [
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/jallum/turbopuffer"}
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Turbopuffer.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:finch, "~> 0.20"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:bypass, "~> 2.1", only: :test}
    ]
  end
end
