defmodule Adjutant.Webhook.Update do
  @moduledoc """
  Functions that can be called by external nodes
  """

  alias Nostrum.Api

  require Logger

  @spec should_update?(String.t(), Nostrum.Snowflake.t()) :: boolean()
  def should_update?(msg, user_id) do
    ask_question(msg, user_id, affirmed: "Updating...", negated: "Not updating...")
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      false
  end

  @spec should_announce?(String.t(), Nostrum.Snowflake.t()) :: boolean
  def should_announce?(msg, user_id) do
    ask_question(msg, user_id, affirmed: "Announcing...", negated: "Not announcing")
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      false
  end

  @spec announce(non_neg_integer | Nostrum.Struct.Message.t(), binary | keyword | map) ::
          Nostrum.Struct.Message.t()
  def announce(channel_id, content) do
    Api.create_message!(channel_id, content)
  end

  @spec dm_error(binary | keyword | map, non_neg_integer) :: Nostrum.Struct.Message.t()
  def dm_error(msg, user_id) do
    dm_channel_id = Adjutant.Util.find_dm_channel_id(user_id)

    Api.create_message!(dm_channel_id, msg)
  end

  defp ask_question(question, user_id, responses) do
    affirmed = responses[:affirmed] || "`Yes` selected"
    negated = responses[:negated] || "`No` selected"
    timeout = responses[:timeout] || "Timed out waiting for response, assuming `No`"

    # constrain to be between 0 and 0xFF_FF_FF
    uuid = Bitwise.band(System.unique_integer([:positive]), 0xFF_FF_FF)

    buttons = Adjutant.ButtonAwait.make_yes_no_buttons(uuid)

    dm_channel_id = Adjutant.Util.find_dm_channel_id(user_id)

    msg =
      Api.create_message!(dm_channel_id, %{
        content: question,
        components: buttons
      })

    btn_response = Adjutant.ButtonAwait.await_btn_click(uuid, nil)

    case btn_response do
      {btn_inter, "yes"} ->
        edit_btn_response(btn_inter, affirmed)
        true

      {btn_inter, "no"} ->
        edit_btn_response(btn_inter, negated)
        false

      nil ->
        Logger.debug("No response received, assuming false")

        Task.start(fn ->
          Api.edit_message!(msg, %{
            content: timeout,
            components: []
          })
        end)

        false
    end
  end

  defp edit_btn_response(inter, content) do
    Task.start(fn ->
      Api.create_interaction_response!(inter, %{
        type: 7,
        data: %{
          content: content,
          components: []
        }
      })
    end)
  end
end
