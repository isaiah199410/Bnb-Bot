defmodule Adjutant.Command.Slash.BNB.Status do
  @moduledoc """
  Command for getting all possible Navi/Virus status effects.
  """

  alias Nostrum.Api
  require Logger

  use Adjutant.Command.Slash, permissions: :everyone, deprecated: true

  @status_names [
    "Angry",
    "Aura",
    "Barrier",
    "Blight",
    "Blind",
    "Confusion",
    "Fatigue",
    "Invisible",
    "Lock",
    "Paralysis",
    "Shield",
    "Stagger"
  ]

  @angry "```Angered Navis are reckless and attack with all their might. While this status is active, Navis with it gain advantage on all Valor Checks. This includes Attack Rolls. They also add their Spirit to the result of Attack Rolls they make until the next time they land a hit against a target. This attack will deal double damage and cause the status to fade.```"

  @aura "```The Aura status surrounds Navis in a powerful cloak of energy that eliminates any attack weaker than it and grants immunity to the effects of Poison and Lava terrain. When a Navi is attacked while under the Aura status, any damage that is less than an amount specified by the aura’s source is negated. Once the aura is hit with damage high enough to match or surpass this amount, it fades.```"

  @barrier "```Navis with the Barrier status are surrounded in a protective field that is able to absorb incoming attacks to prevent damage to the Navi. Barriers often have a capacity for damage that can be absorbed, and when this capacity is met or surpassed the status ends. Wind damage immediately removes this status.```"

  @blight "```See the Blight command.```"

  @blind "```When Blinded, all Attacks Rolls you make against targets at Near range and beyond are made with disadvantage and you automatically fail any Perception Check you’re required to make. This includes Attack Rolls. When you are attacked from your Near range or further, the Attack Roll is made with advantage.```"

  @confusion "```When Confused, you must make every Movement action available to you at the start of your turn. The direction you move in is determined by a roll of 1d6 and interpreted by your GM. You also immediately fail any Info Check you’re required to make while this status is active. This includes Attack Rolls.```"

  @fatigue "```Fatigued Navis are considered weak against every element. Further, when they expend Spirit Points, they must do so at twice the usual rate while following the same restrictions and have disadvantage on all Skill Checks.```"

  @invisible "```An Invisible target is unable to be seen through normal means. In combat, this will grant an increase to your AC until the status is removed. Out of combat, targets will need to make a Perception check with a DC equal to 10 plus twice your Body plus the bonus granted from the source of the status in order to detect your presence, but even then they may not be aware of your exact position. However, Cursor Element Navis have advantage on this Perception check and Cursor Element attacks ignore this boost to AC.```"

  @lock "```When you become Locked, you are unable to make any Move Actions unless doing so would not change your position on the battlefield. You also immediately fail any Agility Check you’re required to make. This includes Attack Rolls.```"

  @paralysis "```Paralysis prevents you from making any Movement or Attack actions on your turn. During this time, you will also immediately fail all Skill Checks that require Strength or Agility. Once the effect ends, you are unable to be Paralyzed again until after you take your next turn.```"

  @shield "```Targets with the Shield status will often reduce the amount of damage received from incoming attacks. This can be a flat decrease or a direct reduction of the number of dice rolled to determine the damage of the attack. However, attacks that deal Break Element damage immediately remove the Shield status from targets and negate any of these effects.```"

  @stagger "```When Staggered, your AC is reduced by your Body Stat. You also immediately fail any Strength Check you’re required to make. This includes Attack Rolls. This effect can be removed at the cost of all your remaining Move Actions for that round.```"

  @impl true
  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.info("Recieved a Status command")

    resp_str =
      case inter.data.options do
        [arg] ->
          status_to_str(arg.value)

        _ ->
          Logger.warning(["Status: bad argument given ", inspect(inter.data.options)])
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
      Enum.map(@status_names, fn name ->
        %{
          name: name,
          value: name
        }
      end)

    %{
      type: 1,
      name: "status",
      description: "Get info about a status",
      options: [
        %{
          type: 3,
          name: "name",
          description: "Status to get info about",
          required: true,
          choices: choices
        }
      ]
    }
  end

  # credo:disable-for-lines:30 Credo.Check.Refactor.CyclomaticComplexity
  defp status_to_str(name) do
    case name do
      "Angry" ->
        @angry

      "Aura" ->
        @aura

      "Barrier" ->
        @barrier

      "Blight" ->
        @blight

      "Blind" ->
        @blind

      "Confusion" ->
        @confusion

      "Fatigue" ->
        @fatigue

      "Invisible" ->
        @invisible

      "Lock" ->
        @lock

      "Paralysis" ->
        @paralysis

      "Shield" ->
        @shield

      "Stagger" ->
        @stagger

      _ ->
        Logger.warning("Got an unknown status: #{name}")
        "Unknown Status"
    end
  end
end
