defmodule AgendaCli.MixProject do
  use Mix.Project

  # Configuracao principal do projeto Mix: nome da app, versao,
  # dependencias e como o comando `mix run` deve iniciar a CLI.
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

  # Dependencias externas usadas no projeto.
  # Jason e o modulo responsavel por serializar e ler o JSON
  # usado por AgendaCli.Store em `contacts.json`.
  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"}
    ]
  end

  # Este alias faz `mix run` chamar AgendaCli.main/1 automaticamente,
  # sem precisar usar `mix run -e ...`.
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
