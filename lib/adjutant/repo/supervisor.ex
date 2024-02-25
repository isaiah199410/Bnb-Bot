defmodule Adjutant.Repo.Supervisor do
  @moduledoc """
  Supervises the sqlite and postgres repo.
  """
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      Adjutant.Repo.SQLite,
      # Adjutant.Repo.Postgres,
      {Oban, oban_config()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp oban_config do
    Application.fetch_env!(:adjutant, Oban)
  end
end
