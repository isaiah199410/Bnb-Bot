defmodule Adjutant.Command.Text.ShutUp do
  @moduledoc """
  Text based command for telling the bot to stop DMing the owner.
  """

  require Logger

  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.info("Recieved a shutup command")

    if Adjutant.Util.owner_msg?(msg) do
      res =
        case :persistent_term.get({:bnb_bot_data, :dm_owner}, nil) do
          nil -> true
          val when is_boolean(val) -> val
        end

      Logger.debug("Currently set to DM messages: #{res}")
      new_val = not res
      :persistent_term.put({:bnb_bot_data, :dm_owner}, new_val)
      Adjutant.Util.react(msg)
    end
  end
end
