defmodule Adjutant.Workers.MessageEdit do
  @moduledoc """
  Oban worker for handling scheduled message edits
  """

  require Logger

  alias Nostrum.Api

  use Oban.Worker, queue: :edit_message

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "channel_id" => channel_id,
          "message_id" => message_id,
          "content" => content,
          "components" => components
        }
      }) do
    res =
      Api.edit_message(channel_id, message_id, %{
        content: content,
        components: components
      })

    case res do
      {:ok, _} ->
        :ok

      {:error, err} ->
        Logger.warning("Error editing message: #{err}")
        {:error, err}
    end
  end

  def perform(%Oban.Job{
        args: %{"channel_id" => channel_id, "message_id" => message_id, "content" => content}
      }) do
    Api.edit_message(channel_id, message_id, %{
      content: content
    })
    |> case do
      {:ok, _} ->
        :ok

      {:error, err} ->
        Logger.warning("Error editing message: #{err}")
        {:error, err}
    end
  end
end
