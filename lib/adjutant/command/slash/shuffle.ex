defmodule Adjutant.Command.Slash.Shuffle do
  @moduledoc """
  Command for suffling a range of numbers.
  """

  alias Nostrum.Api
  require Logger

  use Adjutant.Command.Slash, permissions: :everyone

  @impl true
  @spec call_slash(Nostrum.Struct.Interaction.t()) :: :ignore
  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.info("Recieved a shuffle command")
    [sub_cmd] = inter.data.options

    res =
      case sub_cmd.name do
        "numbers" ->
          number_shuffle_cmd(inter, sub_cmd.options)

        "names" ->
          name_shuffle_cmd(inter, sub_cmd.options)
      end

    case res do
      {:ok, resp_str} ->
        Api.create_interaction_response!(
          inter,
          %{
            type: 4,
            data: %{
              content: resp_str
            }
          }
        )

      {:error, str} ->
        Api.create_interaction_response!(
          inter,
          %{
            type: 4,
            data: %{
              content: str,
              flags: 64
            }
          }
        )
    end

    :ignore
  end

  @impl true
  def get_create_map do
    %{
      type: 1,
      name: "shuffle",
      description: "Shuffle a series of numbers",
      options: [
        %{
          type: 1,
          name: "numbers",
          description: "Shuffle a series of numbers",
          options: [
            %{
              type: 4,
              name: "end",
              description: "The last number in the sequence",
              required: true
            },
            %{
              type: 4,
              name: "start",
              description: "The first number in the sequence, defaults to 1"
            }
          ]
        },
        %{
          type: 1,
          name: "names",
          description: "Shuffle a given set of comma separated names",
          options: [
            %{
              type: 3,
              name: "list",
              description: "The names to shuffle, comma separated",
              required: true
            }
          ]
        }
      ]
    }
  end

  defp number_shuffle_cmd(_inter, opts) do
    case opts do
      [stop, start] ->
        start_val = start.value
        stop_val = stop.value
        shuffle_two_nums(start_val, stop_val)

      [stop] ->
        stop_val = stop.value
        shuffle_single_num(stop_val)
    end
  end

  defp name_shuffle_cmd(_inter, [names]) do
    name_list =
      names.value
      |> String.split(~r/,\s*/)
      |> Stream.map(&String.trim/1)
      |> Stream.filter(fn x -> x != "" end)
      |> Enum.to_list()

    len = length(name_list)

    cond do
      len <= 1 ->
        {:error, "Cowardly refusing to shuffle less than 2 names"}

      len > 64 ->
        {:error, "Cowardly refusing to shuffle more than 64 names"}

      true ->
        list = Enum.shuffle(name_list) |> Enum.intersperse(", ")

        if IO.iodata_length(list) > 1950 do
          {:error, "Resulting message length would be too long"}
        else
          {:ok, IO.iodata_to_binary(list)}
        end
    end
  end

  defp shuffle_nums(start, stop) when start < stop do
    Enum.shuffle(start..stop)
  end

  defp shuffle_nums(stop, start) when start < stop do
    Enum.shuffle(start..stop)
  end

  defp shuffle_single_num(num) when num <= 1 do
    {:error, "Cowardly refusing to shuffle a number less than 2"}
  end

  defp shuffle_single_num(num) when num <= 64 do
    vals = Enum.shuffle(1..num)
    {:ok, "From 1 to #{num} I made:\n```\n[#{Enum.join(vals, ", ")}]\n```"}
  end

  defp shuffle_single_num(_num) do
    {:error, "Cowardly refusing to shuffle a number greater than 64"}
  end

  defp shuffle_two_nums(first, second) when abs(first - second) <= 1 do
    {:error, "Cowardly refusing to shuffle numbers with a difference of less than 2"}
  end

  defp shuffle_two_nums(first, second) when abs(first - second) >= 64 do
    {:error, "Cowardly refusing to shuffle numbers with a difference greater than 64"}
  end

  defp shuffle_two_nums(first, second) do
    {low, high} = Enum.min_max([first, second])
    val = shuffle_nums(first, second)
    {:ok, "From #{low} to #{high} I made:\n```\n[#{Enum.join(val, ", ")}]\n```"}
  end
end
