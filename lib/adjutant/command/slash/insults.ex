defmodule Adjutant.Command.Slash.Insults do
  @moduledoc """
  Module that holds all functions used for modifying "troll" effects.
  """

  alias Nostrum.Api

  require Logger

  @owner_cmd_scope Application.compile_env!(:adjutant, :owner_command_scope)

  use Adjutant.Command.Slash, permissions: :owner, scope: @owner_cmd_scope

  @impl true
  def get_create_map do
    %{
      type: 1,
      name: "insults",
      description: "Modify the troll effects.",
      options: [
        %{
          type: 1,
          name: "add",
          description: "Add a new insult.",
          options: [
            %{
              type: 3,
              name: "insult",
              description: "The insult to add.",
              required: true
            }
          ]
        },
        %{
          type: 1,
          name: "remove",
          description: "Remove an insult.",
          options: [
            %{
              type: 4,
              name: "id",
              description: "The id of the insult to remove.",
              required: true
            }
          ]
        },
        %{
          type: 1,
          name: "list",
          description: "List all insults."
        },
        %{
          type: 1,
          name: "edit",
          description: "Edit an insult.",
          options: [
            %{
              type: 4,
              name: "id",
              description: "The id of the insult to edit.",
              required: true
            },
            %{
              type: 3,
              name: "insult",
              description: "The new insult.",
              required: true
            }
          ]
        }
      ]
    }
  end

  @impl true
  def call_slash(%Nostrum.Struct.Interaction{type: 2} = inter) do
    [sub_cmd] = inter.data.options

    case sub_cmd.name do
      "add" ->
        [opt] = sub_cmd.options
        insult = opt.value
        add_insult(inter, insult)

      "remove" ->
        [opt] = sub_cmd.options
        id = opt.value
        remove_insult(inter, id)

      "list" ->
        list_insults(inter)

      "edit" ->
        [id_opt, insult_opt] = sub_cmd.options
        id = id_opt.value
        insult = insult_opt.value
        edit_insult(inter, id, insult)
    end

    :ignore
  end

  defp add_insult(inter, insult) do
    new_insult = Adjutant.PsychoEffects.Insults.add_new!(insult)

    Api.create_interaction_response!(inter, %{
      type: 4,
      data: %{
        content: "Insult added, with id: #{new_insult.id}"
      }
    })
  end

  defp remove_insult(inter, id) do
    insult = Adjutant.PsychoEffects.Insults.get_by_id(id)

    uuid =
      System.unique_integer([:positive])
      # constrain to be between 0 and 0xFF_FF_FF
      |> Bitwise.band(0xFF_FF_FF)

    buttons = Adjutant.ButtonAwait.make_yes_no_buttons(uuid)

    Api.create_interaction_response!(inter, %{
      type: 4,
      data: %{
        content: "Are you sure you want to remove the insult:\n\n#{insult.insult}",
        components: buttons
      }
    })

    btn_response = Adjutant.ButtonAwait.await_btn_click(uuid, nil)

    case btn_response do
      {btn_inter, "yes"} ->
        Adjutant.PsychoEffects.Insults.delete(insult)
        edit_btn_response(btn_inter, "Insult removed.")

      {btn_inter, "no"} ->
        edit_btn_response(btn_inter, "Insult not removed.")

      nil ->
        Api.edit_interaction_response(inter, %{
          content: "Timed out waiting for a response.",
          components: []
        })
    end
  end

  defp list_insults(inter) do
    content =
      Adjutant.PsychoEffects.Insults.get_all()
      |> Enum.map(fn insult -> "`#{insult.id}`: #{insult.insult}" end)
      |> Enum.intersperse("\n\n")

    content_size = IO.iodata_length(content)

    mesage_count = ceil(content_size / 1900)

    if mesage_count == 1 do
      Api.create_interaction_response!(inter, %{
        type: 4,
        data: %{
          content: IO.iodata_to_binary(content)
        }
      })
    else
      Api.create_interaction_response!(inter, %{
        type: 5
      })

      chunk_size = ceil(length(content) / mesage_count)

      Stream.chunk_every(content, chunk_size)
      |> Enum.each(fn chunk ->
        Api.create_followup_message!(inter.token, %{
          content: IO.iodata_to_binary(chunk)
        })
      end)
    end
  end

  defp edit_insult(inter, id, insult) do
    old_insult = Adjutant.PsychoEffects.Insults.get_by_id(id)

    uuid =
      System.unique_integer([:positive])
      # constrain to be between 0 and 0xFF_FF_FF
      |> Bitwise.band(0xFF_FF_FF)

    buttons = Adjutant.ButtonAwait.make_yes_no_buttons(uuid)

    Api.create_interaction_response!(inter, %{
      type: 4,
      data: %{
        content:
          "Are you sure you want to edit the insult:\n\n#{old_insult.insult}\n\nTo:\n\n#{insult}",
        components: buttons
      }
    })

    btn_response = Adjutant.ButtonAwait.await_btn_click(uuid, nil)

    case btn_response do
      {btn_inter, "yes"} ->
        Adjutant.PsychoEffects.Insults.update!(old_insult, insult)
        edit_btn_response(btn_inter, "Insult edited.")

      {btn_inter, "no"} ->
        edit_btn_response(btn_inter, "Insult not edited.")

      nil ->
        Api.edit_interaction_response(inter, %{
          content: "Timed out waiting for a response.",
          components: []
        })
    end
  end

  defp edit_btn_response(btn_inter, msg) do
    Api.create_interaction_response(btn_inter, %{
      type: 7,
      data: %{
        content: msg,
        components: []
      }
    })
  end
end
