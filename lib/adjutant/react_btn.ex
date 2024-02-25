defmodule Adjutant.ButtonAwait do
  @moduledoc """
  Module for creating buttons that wait for a response from the user.
  """

  alias Adjutant.Library.{Battlechip, NCP, Virus}
  alias Nostrum.Struct.Component.{ActionRow, Button}

  require Logger
  # alias Nostrum.Api

  @doc """
  Creates a list of ActionRows on the input by calling `Adjutant.Library.LibObj.to_btn/2`
  on each list item.

  Raises if there are more than 25 buttons or if the list is empty
  """
  @spec generate_msg_buttons([struct()], boolean()) :: [ActionRow.t()] | no_return()
  def generate_msg_buttons(buttons, disabled \\ false)

  def generate_msg_buttons([], _disabled) do
    raise "Empty List"
  end

  def generate_msg_buttons(content, _disabled) when length(content) > 25 do
    raise "Too many buttons"
  end

  def generate_msg_buttons(content, disabled) do
    row_chunks = Enum.chunk_every(content, 5)

    Enum.map(row_chunks, fn row ->
      Enum.map(row, &Adjutant.Library.LibObj.to_btn(&1, disabled)) |> ActionRow.action_row()
    end)
  end

  @doc """
  Creates a list of ActionRows on the input by calling `Adjutant.Library.LibObj.to_btn/3`
  on each list item.

  Expects an integer uuid to associate with the buttons which must be within the range 0 and 16,777,215 (0xFF_FF_FF)

  Raises if there are more than 25 buttons, if the list is empty, or if the uuid is out of range
  """
  @spec generate_msg_buttons_with_uuid([struct()], boolean(), pos_integer()) ::
          [ActionRow.t()] | no_return()
  def generate_msg_buttons_with_uuid(buttons, disabled \\ false, uuid)

  def generate_msg_buttons_with_uuid([], _disabled, _uuid) do
    raise "Empty List"
  end

  def generate_msg_buttons_with_uuid(content, _disabled, _uuid) when length(content) > 25 do
    raise "Too many buttons"
  end

  def generate_msg_buttons_with_uuid(content, disabled, uuid) when uuid in 0..0xFF_FF_FF do
    # uuid = System.unique_integer([:positive]) |> rem(1000)
    row_chunks = Enum.chunk_every(content, 5)

    Enum.map(row_chunks, fn row ->
      Enum.map(row, &Adjutant.Library.LibObj.to_btn_with_uuid(&1, disabled, uuid))
      |> ActionRow.action_row()
    end)
  end

  @spec generate_persistent_buttons([struct()], boolean()) ::
          [ActionRow.t()] | no_return()
  def generate_persistent_buttons(buttons, disabled \\ false)

  def generate_persistent_buttons([], _disabled) do
    raise "Empty List"
  end

  def generate_persistent_buttons(content, _disabled) when length(content) > 25 do
    raise "Too many buttons"
  end

  def generate_persistent_buttons(content, disabled) do
    row_chunks = Enum.chunk_every(content, 5)

    Enum.map(row_chunks, fn row ->
      Enum.map(row, &Adjutant.Library.LibObj.to_persistent_btn(&1, disabled))
      |> ActionRow.action_row()
    end)
  end

  def make_yes_no_buttons(uuid) when uuid in 0..0xFF_FF_FF do
    uuid_str =
      uuid
      |> Integer.to_string(16)
      |> String.pad_leading(6, "0")

    yes = %{
      type: 2,
      style: 3,
      label: "yes",
      custom_id: "#{uuid_str}_yn_yes"
    }

    no = %{
      type: 2,
      style: 4,
      label: "no",
      custom_id: "#{uuid_str}_yn_no"
    }

    action_row = %{
      type: 1,
      components: [
        yes,
        no
      ]
    }

    [action_row]
  end

  @spec get_confirmation?(Nostrum.Struct.Interaction.t(), String.t()) :: boolean()
  def get_confirmation?(inter, content) do
    uuid =
      System.unique_integer([:positive])
      # constrain to be between 0 and 0xFF_FF_FF
      |> Bitwise.band(0xFF_FF_FF)

    uuid_str =
      uuid
      |> Integer.to_string(16)
      |> String.pad_leading(6, "0")

    buttons =
      [
        Button.interaction_button("yes", "#{uuid_str}_yn_yes", style: 4),
        Button.interaction_button("no", "#{uuid_str}_yn_no", style: 2)
      ]
      |> ActionRow.action_row()
      |> List.wrap()

    Nostrum.Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content: content,
          flags: 64,
          components: buttons
        }
      }
    )

    btn_response = Adjutant.ButtonAwait.await_btn_click(uuid, nil)

    case btn_response do
      {btn_inter, yn} when yn in ["yes", "no"] ->
        Nostrum.Api.create_interaction_response(btn_inter, %{
          type: 7,
          data: %{
            components: []
          }
        })

        yn == "yes"

      nil ->
        Nostrum.Api.edit_interaction_response(inter, %{
          content: "Timed out waiting for response",
          components: []
        })

        false
    end
  end

  @doc """
  Awaits a button click on the given message from a user with the given ID (nil for any user)
  timeout is after 30 seconds
  """
  @spec await_btn_click(
          pos_integer() | Nostrum.Snowflake.t(),
          Nostrum.Snowflake.t() | nil,
          pos_integer()
        ) ::
          {Nostrum.Struct.Interaction.t(), any()}
          | Nostrum.Struct.Interaction.t()
          | nil
          | no_return()
  def await_btn_click(uuid, user_id \\ nil, timeout \\ 30_000) when uuid in 0..0xFF_FF_FF do
    Registry.register(:BUTTON_COLLECTOR, uuid, user_id)
    # Registry.register(:SHUTDOWN_REGISTRY, uuid, user_id)
    Logger.debug("Registering an await click on #{uuid} for #{user_id}")
    btn = await_btn_click_inner(timeout)
    Logger.debug("Got a response to #{uuid} of #{inspect(btn, pretty: true)}")
    Registry.unregister(:BUTTON_COLLECTOR, uuid)
    # Registry.unregister(:SHUTDOWN_REGISTRY, uuid)
    btn
  end

  @spec await_modal_input(pos_integer()) :: Nostrum.Struct.Interaction.t() | nil | no_return()
  def await_modal_input(uuid) when uuid in 0..0xFF_FF_FF do
    Registry.register(:BUTTON_COLLECTOR, uuid, nil)
    # Registry.register(:SHUTDOWN_REGISTRY, uuid, nil)
    Logger.debug("Registering an await modal input on #{uuid}")
    input = await_btn_click_inner(:timer.minutes(30))
    Logger.debug("Got a response to #{uuid} of #{inspect(input, pretty: true)}")
    Registry.unregister(:BUTTON_COLLECTOR, uuid)
    # Registry.unregister(:SHUTDOWN_REGISTRY, uuid)
    input
  end

  def resp_to_btn(%Nostrum.Struct.Interaction{} = inter, id, value \\ nil) do
    Logger.debug("Looking up uuid #{id}")

    case Registry.lookup(:BUTTON_COLLECTOR, id) do
      [{pid, user_id}]
      when is_nil(user_id)
      when inter.user.id == user_id
      when inter.member.user_id == user_id ->
        send(pid, {:btn_click, inter, value})

      _ ->
        Logger.debug("Interaction wasn't registered, or wasn't for said user")

        Nostrum.Api.create_interaction_response!(
          inter,
          %{
            type: 4,
            data: %{
              content:
                "You're not the one that I created this for, or I'm no longer listening for events on it, sorry",
              # 64 is the flag for ephemeral messages
              flags: 64
            }
          }
        )
    end
  end

  def resp_to_persistent_btn(%Nostrum.Struct.Interaction{} = inter, kind, name) do
    res =
      case kind do
        ?c -> Battlechip.get(name)
        ?n -> NCP.get(name)
        ?v -> Virus.get(name)
      end

    resp =
      if is_nil(res) do
        "Seems that one couldn't be found, please inform Major"
      else
        to_string(res)
      end

    Nostrum.Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content: resp
        }
      }
    )
  end

  # default timeout is 30 seconds
  defp await_btn_click_inner(timeout) do
    receive do
      :shutdown ->
        nil

      value ->
        handle_btn_click(value)
    after
      timeout ->
        nil
    end
  end

  defp handle_btn_click({:btn_click, %Nostrum.Struct.Interaction{} = value, nil}) do
    value
  end

  defp handle_btn_click({:btn_click, %Nostrum.Struct.Interaction{} = value, data}) do
    {value, data}
  end

  defp handle_btn_click(other) do
    Logger.error("Recieved message that wasn't a btn click: #{inspect(other)}")
    raise "Inconcievable"
  end
end
