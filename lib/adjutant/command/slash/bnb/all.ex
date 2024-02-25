defmodule Adjutant.Command.Slash.BNB.All do
  @moduledoc """
  Command for searching all BattleChips/Viruses/NPCs for a given name.
  """

  alias Nostrum.Api
  require Logger

  @spec do_btn_response(Nostrum.Struct.Interaction.t(), [
          {float(),
           Adjutant.Library.NCP.t() | Adjutant.Library.Battlechip.t() | Adjutant.Library.Virus.t()}
        ]) :: :ignore
  def do_btn_response(%Nostrum.Struct.Interaction{} = inter, []) do
    Logger.debug("Nothing similar enough found")

    Api.create_interaction_response!(inter, %{
      type: 4,
      data: %{
        content: "I'm sorry, I couldn't find anything with a similar enough name",
        flags: 64
      }
    })

    :ignore
  end

  def do_btn_response(%Nostrum.Struct.Interaction{} = inter, [{_, opt}]) do
    Logger.debug("Found only one option that was similar enough")

    Api.create_interaction_response!(inter, %{
      type: 4,
      data: %{
        content: "#{opt}"
      }
    })

    :ignore
  end

  def do_btn_response(%Nostrum.Struct.Interaction{} = inter, all) do
    Logger.debug(["Found ", to_string(length(all)), " options that were similar enough"])

    obj_list = Enum.map(all, fn {_, opt} -> opt end)

    uuid =
      System.unique_integer([:positive])
      # constrain to be between 0 and 0xFF_FF_FF
      |> Bitwise.band(0xFF_FF_FF)

    buttons = Adjutant.ButtonAwait.generate_msg_buttons_with_uuid(obj_list, uuid)

    Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content: "Did you mean:",
          flags: 64,
          components: buttons
        }
      }
    )

    btn_response = Adjutant.ButtonAwait.await_btn_click(uuid, nil)

    route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

    case btn_response do
      {btn_inter, {kind, name}} ->
        lib_obj = kind_name_to_lib_obj(kind, name)

        edit_task =
          Task.async(fn ->
            Api.create_interaction_response!(btn_inter, %{
              type: 7,
              data: %{
                content: "You selected #{lib_obj.name}",
                components: []
              }
            })
          end)

        resp_task =
          Task.async(fn ->
            name = inter.data.name

            resp_text =
              if is_nil(inter.user) do
                "<@#{inter.member.user_id}> used `/#{name}`\n#{lib_obj}"
              else
                "<@#{inter.user.id}> used `/#{name}`\n#{lib_obj}"
              end

            Api.create_message!(inter.channel_id, resp_text)

            # Api.execute_webhook(inter.application_id, inter.token, %{
            #  content: resp_text
            # })
          end)

        Task.await_many([edit_task, resp_task], :infinity)

      nil ->
        Api.request(:patch, route, %{
          content: "Timed out waiting for response",
          components: []
        })
    end

    :ignore
  end

  defp kind_name_to_lib_obj(kind, name) do
    case kind do
      ?n ->
        Adjutant.Library.NCP.get!(name)

      ?c ->
        Adjutant.Library.Battlechip.get!(name)

      ?v ->
        Adjutant.Library.Virus.get!(name)
    end
  end
end
