defmodule AgendaCli.MixProject do
  use Mix.Project

  def project do
    [
      app: :agenda_cli,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      escript: [main_module: AgendaCli],
      deps: deps()
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
      {:jason, "~> 1.4"}
    ]
  end

  defp aliases do
    [
      run: &run_cli/1
    ]
  end

  defp run_cli(args) do
    Mix.Task.run("compile")
    Mix.Task.run("app.start")
    AgendaCli.main(args)
  end
end
