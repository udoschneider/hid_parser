defmodule HidParser.MixProject do
  use Mix.Project

  def project do
    [
      app: :hid_parser,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      # Dialyzer needs :syntax_tools (via :cerl_prettypr) to format warnings,
      # which code path pruning strips out. Keep pruning only for :prod.
      prune_code_paths: Mix.env() == :prod,
      deps: deps(),
      aliases: [compile: ["hid_parser.fetch_usage_tables", "compile"]],
      dialyzer: dialyzer()
    ]
  end

  # The Mix tasks in lib/mix/tasks call Mix.shell/0, Mix.raise/1 and :crypto,
  # none of which are in the default PLT.
  defp dialyzer do
    [
      plt_add_apps: [:mix, :crypto]
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
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_check, "~> 0.14.0", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev], runtime: false},
      {:doctor, "~> 0.23.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.24.2", only: [:dev, :test], runtime: false}
    ]
  end
end
