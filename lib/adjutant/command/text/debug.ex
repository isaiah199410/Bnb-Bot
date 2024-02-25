defmodule Adjutant.Command.Text.Debug do
  @moduledoc """
  This module contains commands for turning on and off debug mode.
  """

  alias Nostrum.Api
  require Logger

  def call(%Nostrum.Struct.Message{} = msg, []) do
    Logger.info("Got a debug cmd with no args")

    if Adjutant.Util.owner_msg?(msg) do
      Logger.configure(level: :debug)
      Adjutant.Util.react(msg, true)
    end
  end

  def call(%Nostrum.Struct.Message{} = msg, ["on"]) do
    if Adjutant.Util.owner_msg?(msg) do
      Logger.info("Turning on debug")
      Logger.configure(level: :debug)
      Adjutant.Util.react(msg, true)
    end
  end

  def call(%Nostrum.Struct.Message{} = msg, ["off"]) do
    if Adjutant.Util.owner_msg?(msg) do
      Logger.info("Turning off debug")
      Logger.configure(level: :warning)
      Adjutant.Util.react(msg, true)
    end
  end

  def call(%Nostrum.Struct.Message{} = msg, args) do
    if Adjutant.Util.owner_msg?(msg) do
      Logger.info(["Got a debug cmd with bad args: " | Enum.intersperse(args, " ")])

      Api.create_message(
        msg.channel_id,
        "I'm sorry, that is not a valid argument to the Debug command"
      )

      Adjutant.Util.react(msg, false)
    end
  end
end
