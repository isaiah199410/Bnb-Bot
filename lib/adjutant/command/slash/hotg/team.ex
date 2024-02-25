defmodule Adjutant.Command.Slash.HOTG.Team do
  @moduledoc """
  Command for randomly assigning Ranger characters to players in a team.
  """

  alias Nostrum.Api
  require Logger

  use Adjutant.Command.Slash, permissions: :everyone

  @asset_path "./lib/command/slash/hotg/hotg_assets.json"

  @impl true
  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.info("Received a HOTG slash command")

    file =
      @asset_path
      |> File.read!()
      |> Jason.decode!()

    %{
      "rangers" => ranger_list,
      "minions" => minion_list,
      "monsters" => monster_list,
      "bosses" => boss_list
    } = file

    players =
      ranger_list
      |> Enum.take_random(6)
      |> Enum.intersperse(", ")

    minions =
      minion_list
      |> Enum.take_random(2)
      |> Enum.intersperse(", ")

    monsters =
      monster_list
      |> Enum.take_random(2)
      |> Enum.intersperse(", ")

    boss = Enum.random(boss_list)

    resp_str =
      [
        "Rangers: ",
        players,
        "\n",
        "Minions: ",
        minions,
        "\n",
        "Monsters: ",
        monsters,
        "\n",
        "Boss: ",
        boss
      ]

    Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content: IO.iodata_to_binary(resp_str)
        }
      }
    )

    :ignore
  end

  @impl true
  def get_create_map do
    %{
      type: 1,
      name: "morphin",
      description: "Creates a random HOTG game for you."
    }
  end
end
