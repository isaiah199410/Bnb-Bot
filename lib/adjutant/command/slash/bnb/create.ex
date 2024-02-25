defmodule Adjutant.Command.Slash.BNB.Create do
  @moduledoc """
  This module contains commands for creating new Viruses, Chips, and NCPs.

  Currently incomplete, waiting on modal functionality from Discord.
  """

  alias Nostrum.Api
  alias Nostrum.Struct.Component.{ActionRow, TextInput}
  require Logger

  use Adjutant.Command.Slash, permissions: [:owner, :admin]

  @colors [
    "White",
    "Pink",
    "Yellow",
    "Green",
    "Blue",
    "Red",
    "Gray"
  ]

  @impl true
  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    [sub_cmd] = inter.data.options

    case sub_cmd.name do
      "ncp" ->
        create_ncp(inter, sub_cmd.options)
    end

    :ignore
  end

  @impl true
  def get_create_map do
    %{
      type: 1,
      name: "create",
      description: "Create a new library object",
      options: [
        ncp_create_map()
      ]
    }
  end

  defp ncp_create_map do
    color_choices =
      Enum.map(@colors, fn name ->
        %{
          name: name,
          value: String.downcase(name, :ascii)
        }
      end)

    %{
      type: 1,
      name: "ncp",
      description: "Build the JSON object for adding an NCP.",
      options: [
        %{
          type: 3,
          name: "name",
          description: "The name of the NCP.",
          required: true
        },
        %{
          type: 3,
          name: "color",
          description: "The color of the NCP.",
          required: true,
          choices: color_choices
        },
        %{
          type: 4,
          name: "cost",
          description: "The number of EB the NCP costs.",
          min_value: 1,
          max_value: 50,
          required: true
        }
      ]
    }
  end

  defp create_ncp(%Nostrum.Struct.Interaction{} = inter, options) do
    [
      name,
      color,
      cost
    ] = options

    Logger.debug(
      "Got an NCP create request, #{name.name}:#{name.value} #{color.name}:#{color.value} #{cost.name}:#{cost.value}"
    )

    uuid =
      System.unique_integer([:positive])
      # constrain to be between 0 and 0xFF_FF_FF
      |> Bitwise.band(0xFF_FF_FF)

    uuid_str =
      Integer.to_string(uuid, 16)
      |> String.pad_leading(6, "0")

    description_input =
      TextInput.text_input("NCP Description", "Description",
        style: 2,
        min_length: 10,
        placeholder: "Enter a description for the NCP",
        required: true
      )

    Logger.debug(Kernel.inspect(description_input))

    description_input = ActionRow.action_row(description_input)

    Logger.debug(Kernel.inspect(description_input))

    Api.create_interaction_response!(
      inter,
      %{
        type: 9,
        data: %{
          custom_id: uuid_str,
          title: "NCP Description",
          components: [description_input]
        }
      }
    )

    modal_response = Adjutant.ButtonAwait.await_modal_input(uuid)

    unless is_nil(modal_response) do
      Nostrum.Api.create_interaction_response!(
        modal_response,
        %{
          type: 4,
          data: %{
            content: "Success?",
            # 64 is the flag for ephemeral messages
            flags: 64
          }
        }
      )
    end
  end
end
