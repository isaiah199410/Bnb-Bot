defmodule Adjutant.Command.Slash.BNB.Panels do
  @moduledoc """
  Command for getting information about all panel types currently in the game.
  """

  alias Nostrum.Api
  require Logger

  use Adjutant.Command.Slash, permissions: :everyone, deprecated: true

  @panels [
    "Cracked",
    "Grass",
    "Holy",
    "Ice",
    "Lava",
    "Magnet",
    "Metal",
    "Poison",
    "Sand",
    "Sea"
  ]

  @cracked "```\nCracked:\nCracked terrain forces anything attempting to step off of it to make an Endurance check or become Staggered.\n```"
  @grass "```\nGrass:\nWood Navis and Viruses regain HP equal to their Endurance whenever they end their turn while occupying this terrain. However, attacks that deal Fire damage have this damage increased by half their regular damage dice.\n```"
  @holy "```\nHoly:\nAny damage that a target takes while standing on this terrain is reduced by half.\n```"
  @ice "```\nIce:\nShould a target use a Move Action to enter a space of this type, they will immediately slide forward one space in the direction they stepped in. This effect does not apply to Aqua Element targets. Elec attacks deal one and a half times their regular damage to targets standing on Ice terrain regardless of this.\n```"
  @lava "```\nLava:\nAny target save those of the Fire Element that steps on a space of this type immediately takes damage equal to a roll of one of their HP dice and reverts the terrain to normal. Wood Navis and Viruses take twice this damage. If an Aqua attack passes over these spaces, they are reverted to normal terrain.\n```"
  @magnet "```\nMagnet:\nAny target save those of the Elec Element are propelled in a direction determined by a roll of 1d6 and interpreted by the GM when they step on these spaces. Wood attacks that pass over these spaces immediately revert the terrain to normal.\n```"
  @metal "```\nMetal:\nThese spaces are immune to becoming Cracked by any sort of attack, and targets that stand on them have their AC increased by 2.\n```"
  @poison "```\nPoison:\nTargets standing on Poison terrain immediately suffer Blight (Recovery) and take 1d4 damage upon moving into it. For each Attack Action made on Poison terrain, an additional 1d4 Recovery damage is taken. Blight (Recovery) ends when the target starts their turn on a space that does not contain Poison terrain.\n```"
  @sand "```\nSand:\nTargets stepping onto spaces of this type expend two Move Actions instead of one. If the target does not have two Move Actions remaining, they cannot step on these panels unless their Agility is less than 5. Wind attacks gain additional damage dice equal to half their regular value and immediately remove the terrain from these spaces when targeting them.\n```"
  @sea "```\nSea:\nTerrain of this type forces non-Aqua Element targets with less than 5 Agility that occupy it to use two Move Actions when moving away from it. Should these targets not have two Move Actions remanining, they cannot step off these panels. Elec attacks gain damage dice equal to half their regular value on targets standing in these spaces.\n```"

  @impl true
  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.info("Recieved a panel command")

    resp_str =
      case inter.data.options do
        [arg] ->
          panel_to_str(arg.value)

        _ ->
          Logger.warning(["Bad panel args given ", inspect(inter.data.options)])
          "An unknown error has occurred"
      end

    Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content: resp_str
        }
      }
    )

    :ignore
  end

  @impl true
  def get_create_map do
    choices =
      Enum.map(@panels, fn name ->
        %{
          name: name,
          value: name
        }
      end)

    %{
      type: 1,
      name: "panel",
      description: "Get info about a panel type",
      options: [
        %{
          type: 3,
          name: "kind",
          description: "The panel type to get info about",
          required: true,
          choices: choices
        }
      ]
    }
  end

  # credo:disable-for-lines:30 Credo.Check.Refactor.CyclomaticComplexity
  defp panel_to_str(name) do
    case name do
      "Cracked" ->
        @cracked

      "Grass" ->
        @grass

      "Holy" ->
        @holy

      "Ice" ->
        @ice

      "Lava" ->
        @lava

      "Magnet" ->
        @magnet

      "Metal" ->
        @metal

      "Poison" ->
        @poison

      "Sand" ->
        @sand

      "Sea" ->
        @sea

      _ ->
        Logger.warning("Got an unknown panel: #{name}")
        "Unknown Panel"
    end
  end
end
