defmodule CldrCurrencies.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :ex_cldr_currencies,
      version: @version,
      elixir: "~> 1.5",
      name: "Cldr Currencies",
      description: description(),
      source_url: "https://github.com/kipcole9/cldr_currencies",
      docs: docs(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package()
    ]
  end

  defp description do
    """
    Currency localization data encapsulation functions for the Common Locale Data Repository (CLDR).
    """
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
      {:ex_cldr, "~> 1.5"},
      {:poison, "~> 2.1 or ~> 3.1", optional: true},
      {:jason, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.18", only: :dev, optional: true}
    ]
  end

  defp package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache 2.0"],
      links: links(),
      files: [
        "lib",
        "config",
        "mix.exs",
        "README*",
        "CHANGELOG*",
        "LICENSE*"
      ]
    ]
  end

  def docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE.md"],
      logo: "logo.png"
    ]
  end

  def links do
    %{
      "GitHub" => "https://github.com/kipcole9/cldr_curencies",
      "Readme" => "https://github.com/kipcole9/cldr_currencies/blob/v#{@version}/README.md",
      "Changelog" => "https://github.com/kipcole9/cldr_currencies/blob/v#{@version}/CHANGELOG.md"
    }
  end

  defp elixirc_paths(:test), do: ["lib", "mix", "test"]
  defp elixirc_paths(:dev), do: ["lib", "mix"]
  defp elixirc_paths(_), do: ["lib"]
end
