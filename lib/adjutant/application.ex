defmodule Adjutant.Application do
  @moduledoc """
  Defines the Bot's "Application" for auto-startup
  """

  use Application

  def start(_type, _args) do
    children = [
      Adjutant.BotSupervisor,
      Adjutant.Repo.Supervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
