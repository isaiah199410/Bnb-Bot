defmodule Adjutant.Command.Slash.BNB.Chip do
  @moduledoc """
  Contains all BattleChip related commands.

  Currently there are:

  `search` - Searches for a BattleChip

  `dropped-by` - Lists all viruses which drop that particular chip
  """

  alias Adjutant.Library.Battlechip
  alias Nostrum.Api
  require Logger

  use Adjutant.Command.Slash, permissions: :everyone, deprecated: true

  @skills ~w(PER INF TCH STR AGI END CHM VLR AFF None)
  @elements ~w(Fire Aqua Elec Wood Wind Sword Break Cursor Recov Invis Object Null)
  @chip_kinds ~w(Burst Construct Melee Projectile Wave Heal Summon Trap)

  @impl true
  def call_slash(%Nostrum.Struct.Interaction{type: 2} = inter) do
    [sub_cmd] = inter.data.options

    case sub_cmd.name do
      "search" ->
        [opt] = sub_cmd.options
        name = opt.value
        search_chip(inter, name)

      "dropped-by" ->
        [opt] = sub_cmd.options
        name = opt.value
        locate_drops(inter, name)

      "filter" ->
        filter_chip_list(inter, sub_cmd.options)
    end

    :ignore
  end

  def call_slash(%Nostrum.Struct.Interaction{type: 4} = inter) do
    [sub_cmd] = inter.data.options
    [opt] = sub_cmd.options
    name = opt.value

    search_chip(inter, name)
  end

  defp filter_chip_cmd_map do
    skill_choices =
      Enum.map(@skills, fn skill ->
        %{
          name: skill,
          value: String.downcase(skill, :ascii)
        }
      end)

    element_choices =
      Enum.map(@elements, fn element ->
        %{
          name: element,
          value: String.downcase(element, :ascii)
        }
      end)

    chip_kind_choices =
      Enum.map(@chip_kinds, fn chip_kind ->
        %{
          name: chip_kind,
          value: String.downcase(chip_kind, :ascii)
        }
      end)

    %{
      type: 1,
      name: "filter",
      description: "Filter the chip list, errors if more than 25 chips would be returned",
      options: [
        %{
          type: 3,
          name: "skill",
          description: "The skill the chip uses",
          choices: skill_choices
        },
        %{
          type: 3,
          name: "element",
          description: "The element the chip uses",
          choices: element_choices
        },
        %{
          type: 4,
          name: "cr",
          description: "The CR of the chip",
          min_value: 0,
          max_value: 20
        },
        %{
          type: 3,
          name: "blight",
          description: "The blight the chip causes, use null for none",
          choices: element_choices
        },
        %{
          type: 3,
          name: "kind",
          description: "The kind of attack the chip is",
          choices: chip_kind_choices
        },
        %{
          type: 4,
          name: "min_cr",
          description: "The minimum CR of the chip",
          min_value: 1,
          max_value: 20
        },
        %{
          type: 4,
          name: "max_cr",
          description: "The maximum CR of the chip",
          min_value: 1,
          max_value: 20
        },
        %{
          type: 4,
          name: "min_avg_dmg",
          description: "The minimum average damage of the chip",
          min_value: 0
        },
        %{
          type: 4,
          name: "max_avg_dmg",
          description: "The maximum average damage of the chip",
          min_value: 1
        }
      ]
    }
  end

  @impl true
  def get_create_map do
    %{
      type: 1,
      name: "chip",
      description: "The chip group",
      options: [
        %{
          type: 1,
          name: "search",
          description: "Search for a particular chip",
          options: [
            %{
              type: 3,
              name: "name",
              description: "The name of the chip to search for",
              required: true,
              autocomplete: true
            }
          ]
        },
        %{
          type: 1,
          name: "dropped-by",
          description: "List all viruses that drop a particular chip",
          options: [
            %{
              type: 3,
              name: "chip-name",
              description: "The name of the chip",
              required: true,
              autocomplete: true
            }
          ]
        },
        filter_chip_cmd_map()
      ]
    }
  end

  def search_chip(%Nostrum.Struct.Interaction{type: 2} = inter, name) do
    Logger.info(["Searching for the following chip: ", name])

    case Battlechip.get(name) do
      %Battlechip{} = chip ->
        Logger.debug(["Found the following chip: ", chip.name])
        send_found_chip(inter, chip)

      nil ->
        Api.create_interaction_response!(
          inter,
          %{
            type: 4,
            data: %{
              content: "Chip not found",
              flags: 64
            }
          }
        )
    end
  end

  def search_chip(%Nostrum.Struct.Interaction{type: 4} = inter, name) do
    Logger.debug(["Autocomplete Searching for the following chip: ", inspect(name)])

    list =
      Battlechip.get_autocomplete(name)
      |> Enum.map(fn name ->
        # lower_name = String.downcase(name, :ascii)
        %{name: name, value: name}
      end)

    Api.create_interaction_response!(inter, %{
      type: 8,
      data: %{
        choices: list
      }
    })
  end

  def send_found_chip(
        %Nostrum.Struct.Interaction{} = inter,
        %Adjutant.Library.Battlechip{} = chip
      ) do
    Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content: to_string(chip)
        }
      }
    )
  end

  def locate_drops(%Nostrum.Struct.Interaction{} = inter, name) do
    Logger.info(["Locating drops for the following chip: ", name])

    case Adjutant.Library.Battlechip.get(name) do
      %Battlechip{} = chip ->
        send_drops(inter, chip)

      nil ->
        Api.create_interaction_response!(
          inter,
          %{
            type: 4,
            data: %{
              content: "I'm sorry, that chip doesn't exist",
              flags: 64
            }
          }
        )
    end
  end

  def send_drops(%Nostrum.Struct.Interaction{} = inter, %Adjutant.Library.Battlechip{} = chip) do
    drops = Adjutant.Library.Virus.locate_by_drop(chip)

    if Enum.empty?(drops) do
      Api.create_interaction_response!(
        inter,
        %{
          type: 4,
          data: %{
            content: "No viruses drop #{chip.name}."
          }
        }
      )
    else
      buttons = Adjutant.ButtonAwait.generate_persistent_buttons(drops)

      Api.create_interaction_response!(
        inter,
        %{
          type: 4,
          data: %{
            content: "The following viruses drop #{chip.name}:",
            components: buttons
          }
        }
      )

      route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

      buttons = Adjutant.ButtonAwait.generate_persistent_buttons(drops, true)

      # have to get original message as it won't be in the interaction response
      # because reasons

      {:ok, resp} = Api.request(:get, route)
      original = Jason.decode!(resp)

      %{"channel_id" => channel_id, "id" => message_id} = original

      %{
        channel_id: channel_id,
        message_id: message_id,
        content: "The following viruses drop #{chip.name}:",
        components: buttons
      }
      |> Adjutant.Workers.MessageEdit.new(schedule_in: {30, :minutes})
      |> Oban.insert!()
    end
  end

  defp filter_chip_list(inter, []) do
    Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content: "You must specify at least one argument",
          flags: 64
        }
      }
    )
  end

  defp filter_chip_list(inter, options) do
    filters = Enum.map(options, &filter_arg_to_tuple/1)

    with :ok <- validate_cr_args(filters),
         :ok <- validate_dmg_args(filters),
         chips when length(chips) in 1..25 <- Adjutant.Library.Battlechip.run_chip_filter(filters) do
      buttons = Adjutant.ButtonAwait.generate_persistent_buttons(chips)

      Api.create_interaction_response!(
        inter,
        %{
          type: 4,
          data: %{
            content: "found these chips:",
            components: buttons
          }
        }
      )

      route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

      {:ok, resp} = Api.request(:get, route)
      original = Jason.decode!(resp)

      %{"channel_id" => channel_id, "id" => message_id} = original
      buttons = Adjutant.ButtonAwait.generate_persistent_buttons(chips, true)

      %{
        channel_id: channel_id,
        message_id: message_id,
        content: "Found these chips:",
        components: buttons
      }
      |> Adjutant.Workers.MessageEdit.new(schedule_in: {30, :minutes})
      |> Oban.insert!()
    else
      [] ->
        Api.create_interaction_response!(
          inter,
          %{
            type: 4,
            data: %{
              content: "No chips found",
              flags: 64
            }
          }
        )

      {:error, msg} ->
        Api.create_interaction_response!(
          inter,
          %{
            type: 4,
            data: %{
              content: msg,
              flags: 64
            }
          }
        )

      _ ->
        Api.create_interaction_response!(
          inter,
          %{
            type: 4,
            data: %{
              content: "This returned too many chips, I can't send more than 25 at a time",
              flags: 64
            }
          }
        )
    end
  end

  defp filter_arg_to_tuple(arg) do
    case arg.name do
      "skill" ->
        skill = arg.value |> String.upcase(:ascii)
        {:skill, skill}

      "element" ->
        element = arg.value |> String.capitalize(:ascii)
        {:element, element}

      "cr" ->
        {:cr, arg.value}

      "kind" ->
        kind =
          arg.value
          |> String.downcase(:ascii)
          |> String.to_existing_atom()

        {:kind, kind}

      "min_cr" ->
        {:min_cr, arg.value}

      "max_cr" ->
        {:max_cr, arg.value}

      "blight" ->
        element =
          arg.value
          |> String.capitalize(:ascii)

        {:blight, element}

      "min_avg_dmg" ->
        {:min_avg_dmg, arg.value}

      "max_avg_dmg" ->
        {:max_avg_dmg, arg.value}
    end
  end

  defp validate_cr_args(args) do
    case {args[:min_cr], args[:max_cr], args[:cr]} do
      {nil, nil, nil} ->
        :ok

      {nil, _, nil} ->
        :ok

      {_, nil, nil} ->
        :ok

      {nil, nil, _} ->
        :ok

      {min, max, nil} when min > max ->
        {:error, "`min_cr` must be less than `max_cr`"}

      {min, max, nil} when min == max ->
        {:error, "`min_cr` and `max_cr` are equal, juse use `cr`"}

      {_, _, cr} when not is_nil(cr) ->
        {:error, "`cr` cannot be used with `min_cr` or `max_cr`"}

      _ ->
        :ok
    end
  end

  defp validate_dmg_args(args) do
    case {args[:min_avg_dmg], args[:max_avg_dmg]} do
      {nil, nil} ->
        :ok

      {nil, _} ->
        :ok

      {_, nil} ->
        :ok

      {min, max} when min > max ->
        {:error, "min_avg_dmg must be less than max_avg_dmg"}

      _ ->
        :ok
    end
  end
end
