defmodule Adjutant.Command.Slash.BNB.Virus do
  @moduledoc """
  Contains all virus related commands.

  Currently there are:

  `search` - Searches for a virus.

  `cr` - Get a list of all viruses in a given CR.

  `encounter` - Build a random virus encounter.
  """

  alias Adjutant.Library.Virus
  alias Nostrum.Api
  require Logger

  use Adjutant.Command.Slash, permissions: :everyone, deprecated: true

  @impl true
  def call_slash(%Nostrum.Struct.Interaction{type: 2} = inter) do
    [sub_cmd] = inter.data.options

    case sub_cmd.name do
      "search" ->
        [opt] = sub_cmd.options
        name = opt.value
        search_virus(inter, name)

      "cr" ->
        [opt] = sub_cmd.options
        cr = opt.value
        cr_list = Virus.get_cr_list(cr)
        send_cr_list(inter, cr, cr_list)

      "encounter" ->
        build_encounter(inter, sub_cmd.options)
    end

    :ignore
  end

  @impl true
  def call_slash(%Nostrum.Struct.Interaction{type: 4} = inter) do
    [sub_cmd] = inter.data.options

    case sub_cmd.name do
      "search" ->
        [opt] = sub_cmd.options
        name = opt.value
        search_virus(inter, name)
    end

    :ignore
  end

  @impl true
  def get_create_map do
    %{
      type: 1,
      name: "virus",
      description: "The virus group",
      options: [
        %{
          type: 1,
          name: "search",
          description: "Search for a particular virus",
          options: [
            %{
              type: 3,
              name: "name",
              description: "The name of the virus to search for",
              required: true,
              autocomplete: true
            }
          ]
        },
        %{
          type: 1,
          name: "cr",
          description: "get all viruses in a particular CR",
          options: [
            %{
              type: 4,
              name: "cr",
              description: "The CR to search for",
              required: true
            }
          ]
        },
        %{
          type: 1,
          name: "encounter",
          description: "Generate a random encounter",
          options: [
            %{
              type: 4,
              name: "count",
              description: "The number of viruses you want",
              required: true
            },
            %{
              type: 4,
              name: "cr-low",
              description: "The lowest CR of the viruses",
              required: true
            },
            %{
              type: 4,
              name: "cr-high",
              description: "The highest CR of the viruses",
              required: false
            }
          ]
        }
      ]
    }
  end

  defp search_virus(%Nostrum.Struct.Interaction{type: 2} = inter, name) do
    Logger.info(["Searching for the following virus: ", name])

    case Virus.get(name) do
      %Virus{} = virus ->
        Logger.debug(["Found the following virus: ", virus.name])
        send_found_virus(inter, virus)

      nil ->
        Api.create_interaction_response!(
          inter,
          %{
            type: 4,
            data: %{
              content: "Virus not found",
              flags: 64
            }
          }
        )
    end
  end

  defp search_virus(%Nostrum.Struct.Interaction{type: 4} = inter, name) do
    Logger.debug(["Autocomplete searching for the following virus: ", inspect(name)])

    list =
      Virus.get_autocomplete(name)
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

  defp send_cr_list(inter, cr, []) do
    Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content: "There are no viruses in CR #{cr}",
          flags: 64
        }
      }
    )
  end

  defp send_cr_list(inter, cr, cr_list) do
    buttons = Adjutant.ButtonAwait.generate_persistent_buttons(cr_list)

    Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content: "These viruses are in CR #{cr}:",
          components: buttons
        }
      }
    )

    route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

    buttons = Adjutant.ButtonAwait.generate_persistent_buttons(cr_list, true)

    {:ok, resp} = Api.request(:get, route)
    original = Jason.decode!(resp)

    %{"channel_id" => channel_id, "id" => message_id} = original

    %{
      channel_id: channel_id,
      message_id: message_id,
      content: "These viruses are in CR #{cr}:",
      components: buttons
    }
    |> Adjutant.Workers.MessageEdit.new(schedule_in: {30, :minutes})
    |> Oban.insert!()
  end

  defp build_encounter(inter, [count | _rest]) when count.value > 25 or count.value < 1 do
    Logger.info([
      "Got asked to build an encounter with ",
      "#{count.value}",
      " viruses. Cowardly refusing."
    ])

    Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content:
            "Cowardly refusing to build an encounter with less than 1 or more than 25 viruses",
          flags: 64
        }
      }
    )
  end

  defp build_encounter(inter, [%{value: count}, %{value: cr}]) do
    Logger.info([
      "Building an encounter with ",
      "#{count}",
      " viruses in CR ",
      "#{cr}"
    ])

    viruses = Virus.make_encounter(count, cr)

    send_encounter(inter, viruses)
  end

  defp build_encounter(inter, [%{value: _count} = ct_arg, %{value: cr1} = cr_arg, %{value: cr2}])
       when cr1 == cr2 do
    build_encounter(inter, [ct_arg, cr_arg])
  end

  defp build_encounter(inter, [%{value: count}, %{value: cr1}, %{value: cr2}]) do
    {cr_low, cr_high} = if cr1 < cr2, do: {cr1, cr2}, else: {cr2, cr1}

    Logger.info([
      "Building an encounter with ",
      "#{count}",
      " viruses in CR ",
      "#{cr_low}",
      " to ",
      "#{cr_high}"
    ])

    viruses = Virus.make_encounter(count, cr_low, cr_high)

    send_encounter(inter, viruses)
  end

  defp send_encounter(inter, []) do
    Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content: "I'm sorry, I couldn't find any viruses in the given CRs",
          flags: 64
        }
      }
    )
  end

  @spec send_encounter(Nostrum.Struct.Interaction.t(), [Virus.t()]) :: :ignore
  defp send_encounter(inter, viruses) do
    names =
      Enum.map_join(viruses, ", ", fn virus ->
        virus.name
      end)

    buttons =
      Enum.sort_by(viruses, fn virus -> virus.name end)
      |> Enum.dedup()
      |> Adjutant.ButtonAwait.generate_persistent_buttons()

    Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content: names,
          components: buttons
        }
      }
    )

    route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

    {:ok, resp} = Api.request(:get, route)
    original = Jason.decode!(resp)

    %{"channel_id" => channel_id, "id" => message_id} = original

    %{
      channel_id: channel_id,
      message_id: message_id,
      content: names,
      components: []
    }
    |> Adjutant.Workers.MessageEdit.new(schedule_in: {30, :minutes})
    |> Oban.insert!()

    :ignore
  end

  def send_found_virus(%Nostrum.Struct.Interaction{} = inter, virus) do
    Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content: to_string(virus)
        }
      }
    )
  end
end
