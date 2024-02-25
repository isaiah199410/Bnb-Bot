defmodule Adjutant.Command.Slash.Dice do
  @moduledoc """
  Die roll command
  """

  alias Nostrum.Api
  alias Nostrum.Struct.ApplicationCommandInteractionDataOption, as: Option
  require Logger

  use Adjutant.Command.Slash, permissions: :everyone

  @impl true
  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    die_str =
      case inter.data.options do
        [%Option{value: value}] ->
          value

        _ ->
          "1d20"
      end

    Logger.info(["Got a request to roll ", die_str])

    roll_result =
      if String.match?(die_str, ~r/^(?:\d+d\d+|\d+)(?:\s*\+\s*\d+d\d+|\s*\+\s*\d+)*$/) do
        String.replace(die_str, ~r/\s+/, "") |> roll_dice()
      else
        {:error, "An invalid character was found, must be in the format XdY[ + X[dY]]"}
      end

    case roll_result do
      {:error, text} ->
        Api.create_interaction_response!(inter, %{
          type: 4,
          data: %{
            content: text,
            flags: 64
          }
        })

      {:ok, roll} ->
        Api.create_interaction_response!(inter, %{
          type: 4,
          data: %{
            content: roll
          }
        })
    end

    :ignore
  end

  @impl true
  def get_create_map do
    %{
      type: 1,
      name: "roll",
      description: "rolls XdY[ + X[dY]] dice, defaults to 1d20",
      options: [
        %{
          type: 3,
          name: "to-roll",
          description: "The dice to roll"
        }
      ]
    }
  end

  @spec roll_dice(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  defp roll_dice(die_str) do
    rolls = String.split(die_str, "+")

    case do_roll([], rolls) do
      res when is_list(res) ->
        die_result = Enum.sum(res)
        res = Enum.reverse(res)
        {:ok, "On #{die_str}, you rolled: #{die_result}\n#{inspect(res, charlists: :as_lists)}"}

      res when is_bitstring(res) ->
        {:error, res}
    end
  end

  defp do_roll(count, []) do
    count
  end

  defp do_roll(count, [to_roll | rest]) do
    vals = String.split(to_roll, "d")
    die_and_size = Enum.map(vals, fn val -> String.to_integer(val) end)

    count =
      case die_and_size do
        # 0xFFFF is the max value for a uint16
        [num, size] when size > 0 and num in 1..0xFF_FF ->
          Logger.debug("Rolling #{num}d#{size}")
          roll_die(num, size, count)

        [num] ->
          [num | count]

        _ ->
          :error
      end

    case count do
      :error -> "Cowardly refusing to perform an insane operation"
      nums -> do_roll(nums, rest)
    end
  end

  defp roll_die(0, _size, count) do
    count
  end

  defp roll_die(num_rem, size, count) do
    result = Enum.random(1..size)
    # count = count ++ [result]
    roll_die(num_rem - 1, size, [result | count])
  end
end
