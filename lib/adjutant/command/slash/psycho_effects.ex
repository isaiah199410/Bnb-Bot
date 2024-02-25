defmodule Adjutant.Command.Slash.PsychoEffects do
  @moduledoc """
  Command for denying the psycho effects in a channel.

  Note: This only means that the phrase "resolve all psycho effects" will not
  work in the channel. It does not mean that the psycho effects will not be
  applied to the channel.
  """

  alias Nostrum.Api
  alias Nostrum.Struct.ApplicationCommandInteractionDataOption, as: Option
  alias Nostrum.Struct.Interaction

  require Logger

  @cmd_scope Application.compile_env!(:adjutant, :primary_guild_id)

  use Adjutant.Command.Slash, permissions: [:admin, :owner], scope: @cmd_scope

  @impl true
  def get_create_map do
    perms_string =
      :manage_channels
      |> Nostrum.Permission.to_bit()
      |> to_string()

    %{
      type: 1,
      name: "psycho-effects",
      description: "Allow or deny the psycho effects in a channel.",
      default_member_permissions: perms_string,
      options: [
        %{
          type: 1,
          name: "deny",
          description: "Deny \"resolve all psycho effects\" in a channel.",
          options: [
            %{
              type: 7,
              name: "channel",
              description: "The channel to deny the psycho effects in.",
              channel_types: [0],
              required: true
            }
          ]
        },
        %{
          type: 1,
          name: "allow",
          description: "Allow \"resolve all psycho effects\" in a channel.",
          options: [
            %{
              type: 7,
              name: "channel",
              description: "The channel to allow the psycho effects in.",
              channel_types: [0],
              required: true
            }
          ]
        }
      ]
    }
  end

  @impl true
  def call_slash(%Interaction{type: 2} = inter) do
    Logger.info("Psycho effects command called, #{inspect(inter)}")

    case inter.data.options do
      [%Option{name: "allow"} | _] ->
        allow(inter)

      [%Option{name: "deny"} | _] ->
        deny(inter)
    end

    Api.create_interaction_response(inter, %{
      type: 4,
      data: %{
        content: "This command is not meant to be used directly. Please use the subcommands.",
        flags: 64
      }
    })
  end

  defp allow(inter) do
    {channel_id, _channel_data} =
      inter.data.resolved.channels
      |> Map.to_list()
      |> List.first()

    Adjutant.PsychoEffects.Channel.allow_channel(channel_id)
  end

  def deny(inter) do
    {channel_id, channel_data} =
      inter.data.resolved.channels
      |> Map.to_list()
      |> List.first()

    guild_id = channel_data.guild_id
    user_id = inter.member.user_id

    Adjutant.PsychoEffects.Channel.deny_channel(%{
      id: channel_id,
      guild_id: guild_id,
      set_by: user_id
    })

    Api.create_interaction_response(inter, %{
      type: 4,
      data: %{
        content: "Psycho effects denied in channel <##{channel_id}>.",
        flags: 64
      }
    })
  end
end
