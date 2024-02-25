defmodule Adjutant.Command.Slash.RemindMe do
  @moduledoc """
  Command to set a reminder, uses `Oban` under the hood
  """

  alias Adjutant.Workers.Reminder, as: ReminderWorker
  alias Nostrum.Api
  require Logger

  use Adjutant.Command.Slash, permissions: :everyone

  @impl true
  @spec call_slash(Nostrum.Struct.Interaction.t()) :: :ignore
  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.info("Recieved a remind me command")

    {amt, unit, message, repeat} =
      case inter.data.options do
        [amt, unit, message] ->
          {amt.value, unit.value, message.value, false}

        [amt, unit, message, repeat] ->
          {amt.value, unit.value, message.value, repeat.value}
      end

    channel_id = get_channel_id(inter)
    {schedule_in, repeatable} = schedule_in(amt, unit)
    timestamp = System.os_time(:second)

    cond do
      repeat == true and repeatable == :not_repeatable ->
        Logger.debug("Received a repeatable remind me command with a non-repeatable schedule")
        too_short_interval_response(inter)

      send_response(inter, schedule_in, message) == :ok ->
        %{
          message: message,
          channel_id: channel_id,
          timestamp: timestamp,
          repeat: repeat,
          # since json doesn't support tuples, we're going to use a 2-element array
          interval: Tuple.to_list(schedule_in)
        }
        |> ReminderWorker.new(schedule_in: schedule_in)
        |> Oban.insert!()

      true ->
        :ignore
    end

    :ignore
  end

  @impl true
  def get_create_map do
    %{
      type: 1,
      name: "remind-me",
      description: "Sets a reminder for yourself in the future",
      options: [
        %{
          type: 4,
          name: "in",
          description: "Sets the time to remind you in",
          min_value: 1,
          max_value: 60,
          required: true
        },
        %{
          type: 3,
          name: "units",
          description: "Sets the units of time to remind you in",
          required: true,
          choices: [
            %{
              name: "minute(s)",
              value: "minutes"
            },
            %{
              name: "hour(s)",
              value: "hours"
            },
            %{
              name: "day(s)",
              value: "days"
            },
            %{
              name: "week(s)",
              value: "weeks"
            },
            %{
              name: "month(s)",
              value: "months"
            }
          ]
        },
        %{
          type: 3,
          name: "to",
          description: "Sets the message to remind you with",
          required: true
        },
        %{
          type: 5,
          name: "repeat",
          description: "Sets if the reminder should be repeated"
        }
      ]
    }
  end

  def reschedule_reminder(channel_id, reminder_text, {period, units}) do
    uuid =
      System.unique_integer([:positive])
      # constrain to be between 0 and 0xFF_FF_FF
      |> Bitwise.band(0xFF_FF_FF)

    buttons = Adjutant.ButtonAwait.make_yes_no_buttons(uuid)

    {msg_period, msg_units} =
      if units == "weeks" and rem(period, 4) == 0 do
        {div(period, 4), "month(s)"}
      else
        {period, units}
      end

    msg =
      Api.create_message!(channel_id, %{
        content: "Should I remind you again in #{msg_period} #{msg_units}?",
        components: buttons
      })

    btn_response = Adjutant.ButtonAwait.await_btn_click(uuid, nil, :timer.hours(5))

    case btn_response do
      {btn_inter, "yes"} ->
        edit_btn_response(btn_inter, "I'll remind you again in #{msg_period} #{msg_units}")
        true

        {interval, _} = schedule_in(period, units)
        timestamp = System.os_time(:second)

        %{
          message: reminder_text,
          channel_id: channel_id,
          timestamp: timestamp,
          repeat: true,
          # since json doesn't support tuples, we're going to use a 2-element array
          interval: Tuple.to_list(interval)
        }
        |> ReminderWorker.new(schedule_in: interval)
        |> Oban.insert!()

      {btn_inter, "no"} ->
        edit_btn_response(btn_inter, "Okay, I won't remind you again")
        false

      nil ->
        Logger.debug("No response received, assuming true")

        Api.edit_message!(msg, %{
          content:
            "Timed out waiting for response, I'll remind you again in #{msg_period} #{msg_units}",
          components: []
        })

        false
    end
  end

  defp get_channel_id(inter) do
    if is_nil(inter.guild_id) do
      inter.channel_id
    else
      Api.create_dm!(inter.member.user_id).id
    end
  end

  defp edit_btn_response(inter, msg) do
    Api.create_interaction_response!(inter, %{
      type: 7,
      data: %{
        content: msg,
        components: []
      }
    })
  end

  defp schedule_in(1, unit) do
    case unit do
      "minutes" ->
        {{1, :minute}, :not_repeatable}

      "hours" ->
        {{1, :hour}, :not_repeatable}

      "days" ->
        {{1, :day}, :repeatable}

      "weeks" ->
        {{1, :week}, :repeatable}

      "months" ->
        {{4, :weeks}, :repeatable}
    end
  end

  defp schedule_in(amt, unit) do
    case unit do
      "hours" when amt >= 8 ->
        {{amt, :hours}, :repeatable}

      "hours" ->
        {{amt, :hours}, :not_repeatable}

      "minutes" ->
        {{amt, :minutes}, :not_repeatable}

      "days" ->
        {{amt, :days}, :repeatable}

      "weeks" ->
        {{amt, :weeks}, :repeatable}

      "months" ->
        {{4 * amt, :weeks}, :repeatable}
    end
  end

  defp send_response(inter, {reminder_in, reminder_in_units}, reminder_to) do
    if String.length(reminder_to) > 1500 do
      Logger.info("Reminder too long, sending error message")

      Api.create_interaction_response!(inter, %{
        type: 4,
        data: %{
          content: "Your reminder was too long to send, please try again with a shorter message",
          flags: 64
        }
      })

      {:error, "Reminder too long"}
    else
      Api.create_interaction_response!(inter, %{
        type: 4,
        data: %{
          content: "In #{reminder_in} #{reminder_in_units} I'll remind you to:\n\n#{reminder_to}",
          flags: 64
        }
      })

      :ok
    end
  end

  defp too_short_interval_response(inter) do
    Api.create_interaction_response!(inter, %{
      type: 4,
      data: %{
        content:
          "Cowardly refusing to create a repeating reminder with an interval of less than 8 hours",
        flags: 64
      }
    })
  end
end
