defmodule ElixirBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :adjutant,
      version: "0.1.4",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        adjutant: [
          version: "0.3.0",
          applications: [
            adjutant: :permanent
          ],
          cookie: get_cookie()
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Adjutant.Application, []},
      extra_applications: [:logger, :runtime_tools, :mnesia]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nostrum,
       git: "https://github.com/Th3-M4jor/nostrum.git",
       ref: "581d101ada269c0dfa0821371e1139d1e1829c40"},
      # {:nostrum, path: "../nostrum"},
      {:jason, "~> 1.2"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, "~> 0.15"},
      {:ecto_sqlite3, "~> 0.12.0"},
      {:oban, "~> 2.12"},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp get_cookie do
    case File.read("COOKIE") do
      {:ok, cookie} ->
        cookie

      {:error, _err} ->
        unless Mix.env() == :test do
          IO.warn(
            "Could not read COOKIE file, using default cookie. Not recommended for production."
          )
        end

        "SOME_COOKIE"
    end
  end
end
