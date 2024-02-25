defmodule Adjutant.Command.Text.Die do
  @moduledoc """
  This module contains the text command for shutting down the bot.
  """

  require Logger

  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.info("Recieved a die command")

    if Adjutant.Util.owner_msg?(msg) do
      # get all processes that are awaiting user input and tell them to stop
      pid_list = Registry.select(:BUTTON_COLLECTOR, [{{:_, :"$1", :_}, [], [:"$1"]}])

      process_ct = length(pid_list)

      Logger.debug("Found #{process_ct} processes to kill before shutting down")

      for pid <- pid_list do
        Process.monitor(pid)
        send(pid, :shutdown)
      end

      Adjutant.Util.react(msg, true)

      flush_down(process_ct)

      System.stop(0)
    end
  end

  def flush_down(0), do: nil

  def flush_down(process_ct) when is_integer(process_ct) do
    receive do
      {:DOWN, _ref, :process, _object, _reason} ->
        flush_down(process_ct - 1)
        # code
    after
      30_000 -> nil
    end
  end
end
