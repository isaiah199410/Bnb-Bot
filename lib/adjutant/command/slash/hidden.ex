defmodule Adjutant.Command.Slash.Hidden do
  @moduledoc """
  Module that defines "hidden" commands.

  `die` to shutdown the bot.

  `debug` to toggle debug mode.

  `shut_up` to toggle if the bot should DM the owner.

  `add_to_bans` to add people to the list of who would be banned by...

  `salt the earth` to ban everyone on the list of people to ban from the server.

  `list_bans` to list the people who would be banned from the server.
  """
  require Logger

  alias Nostrum.Api
  alias Nostrum.Struct.ApplicationCommandInteractionDataOption, as: Option

  alias Adjutant.Command.Slash.AddToBans

  @hidden_cmd_scope Application.compile_env!(:adjutant, :hidden_command_scope)

  use Adjutant.Command.Slash,
    permissions: [:owner, :admin],
    scope: @hidden_cmd_scope

  @doc """
  Override the `call` method since this command works weirdly.
  """
  def call(inter) do
    call_slash(inter)
  end

  @ownercmds ["die", "debug", "shut_up", "add_to_bans", "salt_the_earth", "list_bans"]
  @admincmds ["die", "add_to_bans", "salt_the_earth", "list_bans"]

  @impl true
  @spec call_slash(Nostrum.Struct.Interaction.t()) :: :ignore
  def call_slash(%Nostrum.Struct.Interaction{type: 2} = inter) do
    case inter.data.options do
      [%Option{value: "die"} | _] ->
        Logger.info("Adjutant.Commands.Hidden.call_slash: die")
        die(inter)

      [%Option{value: "debug"} | args] ->
        Logger.info(["Adjutant.Commands.Hidden.call_slash: debug ", inspect(args)])
        debug(inter, args)

      [%Option{value: "shut_up"} | _] ->
        Logger.info("Adjutant.Commands.Hidden.call_slash: shut_up")
        shut_up(inter)

      [%Option{value: "add_to_bans"} | args] ->
        Logger.info("Adjutant.Commands.Hidden.call_slash: add_to_bans")
        AddToBans.add_to_bans(inter, args)

      [%Option{value: "salt_the_earth"} | _] ->
        Logger.info("Adjutant.Commands.Hidden.call_slash: salt_the_earth")
        AddToBans.salt_the_earth(inter)

      [%Option{value: "list_bans"} | _] ->
        Logger.info("Adjutant.Commands.Hidden.call_slash: list_bans")
        AddToBans.list_bans(inter)

      _ ->
        Logger.info("Adjutant.Commands.Hidden.call_slash: unknown")

        Api.create_interaction_response(inter, %{
          type: 4,
          data: %{
            content: "You don't have permission to do that",
            flags: 64
          }
        })
    end

    :ignore
  end

  @impl true
  def call_slash(%Nostrum.Struct.Interaction{type: 4} = inter) do
    Logger.debug("Recieved an autocomplete request for a hidden command")

    list =
      cond do
        Adjutant.Util.owner_msg?(inter) ->
          @ownercmds

        Adjutant.Util.admin_msg?(inter) ->
          @admincmds

        true ->
          []
      end

    resp =
      Enum.map(list, fn cmd ->
        %{name: cmd, value: cmd}
      end)

    Api.create_interaction_response!(inter, %{
      type: 8,
      data: %{
        choices: resp
      }
    })
  end

  @impl true
  def get_create_map do
    %{
      type: 1,
      name: "hidden",
      description: "hidden owner/admin only commands",
      options: [
        %{
          type: 3,
          name: "command-name",
          description: "the name of the hidden command",
          required: true,
          autocomplete: true
        },
        %{
          type: 3,
          name: "args",
          description: "the arguments to the hidden command",
          required: false
        }
      ],
      dm_permission: false,
      default_member_permissions: "0"
    }
  end

  defp die(inter) do
    if Adjutant.Util.owner_msg?(inter) or Adjutant.Util.admin_msg?(inter) do
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "Shutting down",
          flags: 64
        }
      })

      # get all processes that are awaiting user input and tell them to stop
      pid_list = Registry.select(:BUTTON_COLLECTOR, [{{:_, :"$1", :_}, [], [:"$1"]}])

      process_ct = length(pid_list)

      Logger.debug("Found #{process_ct} processes to kill before shutting down")

      for pid <- pid_list do
        Process.monitor(pid)
        send(pid, :shutdown)
      end

      flush_down(process_ct)

      System.stop(0)
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end

  defp flush_down(0), do: nil

  defp flush_down(process_ct) when is_integer(process_ct) do
    receive do
      {:DOWN, _ref, :process, _object, _reason} ->
        flush_down(process_ct - 1)
        # code
    after
      30_000 -> nil
    end
  end

  defp debug(inter, []) do
    if Adjutant.Util.owner_msg?(inter) do
      Logger.configure(level: :debug)

      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "Debug logging on",
          flags: 64
        }
      })
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end

  defp debug(inter, [%Nostrum.Struct.ApplicationCommandInteractionDataOption{value: "on"}]) do
    debug(inter, [])
  end

  defp debug(inter, [%Nostrum.Struct.ApplicationCommandInteractionDataOption{value: "dump"}]) do
    if Adjutant.Util.owner_msg?(inter) do
      Logger.debug("Dumping the current state of the bot")

      Nostrum.Api.create_interaction_response!(inter, %{
        type: 5,
        data: %{
          flags: 64
        }
      })

      # Adjutant.Commands.Audit.dump_log()

      {lines1, lines2} = Adjutant.Command.Text.Audit.get_formatted(20) |> Enum.split(10)
      lines1 = lines1 |> Enum.intersperse("\n\n")
      lines2 = lines2 |> Enum.intersperse("\n\n")

      Api.create_followup_message!(inter.token, %{
        content: "log_dump.txt written",
        files: [%{name: "log_dump1.txt", body: lines1}, %{name: "log_dump2.txt", body: lines2}]
      })
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end

  defp debug(inter, [%Nostrum.Struct.ApplicationCommandInteractionDataOption{value: "off"}]) do
    if Adjutant.Util.owner_msg?(inter) do
      Logger.configure(level: :warning)

      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "Debug logging off",
          flags: 64
        }
      })
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end

  defp debug(inter, _unknown) do
    if Adjutant.Util.owner_msg?(inter) do
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "That is an invalid argument type",
          flags: 64
        }
      })
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end

  defp shut_up(inter) do
    if Adjutant.Util.owner_msg?(inter) do
      res =
        case :persistent_term.get({:bnb_bot_data, :dm_owner}, nil) do
          nil -> true
          val when is_boolean(val) -> val
        end

      Logger.debug("Currently set to DM messages: #{res}")
      new_val = not res
      :persistent_term.put({:bnb_bot_data, :dm_owner}, new_val)

      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "Shutting up",
          flags: 64
        }
      })
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end
end
