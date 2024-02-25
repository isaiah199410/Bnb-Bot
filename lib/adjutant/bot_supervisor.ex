defmodule Adjutant.BotSupervisor do
  @moduledoc """
  Main entry point for the bot.
  """

  require Logger
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.debug("Starting Supervisor")

    button_collector = Registry.child_spec(keys: :unique, name: :BUTTON_COLLECTOR)

    children = [button_collector, Adjutant.Consumer]

    res = Supervisor.init(children, strategy: :one_for_one)
    Logger.debug("Supervisor started")
    # :ignore
    res
  end
end
