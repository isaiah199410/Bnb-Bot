defmodule Adjutant.Command.Text.Audit do
  @moduledoc """
  Text based command for getting debug/error log information.
  """

  # alias Nostrum.Api
  require Logger
  import Ecto.Query

  alias Nostrum.Struct.Message

  @log_file_name "log_dump.txt"

  def call(%Message{} = msg, []) do
    Logger.info("Got an audit cmd with no args")

    {_, acc, _} =
      get_entries()
      |> Enum.map(&format_entry/1)
      |> Enum.reduce({msg, [], 0}, &join_entries/2)

    text = IO.iodata_to_binary(acc)

    Nostrum.Api.create_message!(msg, text)
  end

  def call(%Message{} = msg, ["id", id]) do
    Logger.info("Got an audit cmd with id")

    id = String.to_integer(id)

    text =
      from(log in Adjutant.LogLine, where: log.id == ^id)
      |> Adjutant.Repo.SQLite.one()
      |> format_entry()

    Nostrum.Api.create_message(msg, text)
  end

  def call(%Message{} = msg, ["count", ct]) do
    Logger.info("Got an audit cmd with count")

    ct = String.to_integer(ct)

    text =
      get_entries(ct)
      |> Enum.map(&format_entry/1)
      |> IO.iodata_to_binary()

    Nostrum.Api.create_message(msg, text)
  end

  def call(%Message{channel_id: channel_id} = msg, ["dump"]) do
    Logger.info("Got an audit cmd for \"dump\"")

    typing_task = Task.async(fn -> Nostrum.Api.start_typing(channel_id) end)

    dump_log()

    uuid =
      System.unique_integer([:positive])
      # constrain to be between 0 and 0xFF_FF_FF
      |> Bitwise.band(0xFF_FF_FF)

    buttons = Adjutant.ButtonAwait.make_yes_no_buttons(uuid)

    # wait for the typing task to finish
    # before sending the message
    # otherwise sometimes the typing indicator
    # is sent after the below message on rare occasions
    Task.await(typing_task)

    bot_msg =
      Nostrum.Api.create_message!(msg, %{
        content: "Dumped log to log_dump.txt, do you want the file?",
        components: buttons
      })

    resp = Adjutant.ButtonAwait.await_btn_click(uuid, msg.author.id)

    case resp do
      {btn_inter, "yes"} ->
        Nostrum.Api.create_interaction_response(btn_inter, %{
          type: 7,
          data: %{
            content: "Dumped log to log_dump.txt",
            components: [],
            file: @log_file_name
          }
        })

      {btn_inter, "no"} ->
        Nostrum.Api.create_interaction_response(btn_inter, %{
          type: 7,
          data: %{
            content: "Dumped log to log_dump.txt",
            components: []
          }
        })

      nil ->
        Nostrum.Api.edit_message(bot_msg, %{
          content: "Dumped log to log_dump.txt",
          components: []
        })
    end
  end

  def call(%Message{} = msg, _) do
    Logger.info("Got an audit command with unknown args")

    Nostrum.Api.create_message(msg, "I didn't recognize the args for that one")
  end

  def last_one do
    Adjutant.LogLine
    |> last()
    |> Adjutant.Repo.SQLite.one()
  end

  @spec get_entries(non_neg_integer()) :: [Adjutant.LogLine.t()]
  def get_entries(count \\ 10) do
    query = from(log in Adjutant.LogLine, order_by: [desc: log.id], limit: ^count)
    Adjutant.Repo.SQLite.all(query) |> Enum.reverse()
  end

  def get_formatted(count \\ 10) do
    from(log in Adjutant.LogLine, order_by: [desc: log.id], limit: ^count)
    |> Adjutant.Repo.SQLite.all()
    |> Enum.reverse()
    |> Enum.map(&format_entry/1)
  end

  def dump_log do
    # Using :file.open/2 instead of File.open/2 because
    # we are using the :raw option for increased write performance
    # and want to be consistent with module usage
    {:ok, file_ptr} = :file.open(@log_file_name, [:write, :delayed_write, :raw])

    line_stream =
      from(log in Adjutant.LogLine, order_by: [asc: log.inserted_at])
      |> Adjutant.Repo.SQLite.stream()
      |> Stream.map(&format_entry/1)
      |> Stream.intersperse("\n\n")
      |> Stream.each(fn x ->
        # to_iovec's point over to_binary is that it cuts down on copying
        # binaries that are off-heap between processes
        # while not having to build an entirely new binary in memory
        x = :erlang.iolist_to_iovec(x)
        :file.write(file_ptr, x)
      end)

    # streams must happen in a transaction
    Adjutant.Repo.SQLite.transaction(fn ->
      Stream.run(line_stream)
    end)

    :ok = :file.close(file_ptr)
  end

  defp format_entry(%Adjutant.LogLine{inserted_at: inserted_at, level: level, message: log_msg}) do
    [
      NaiveDateTime.to_string(inserted_at),
      " [",
      to_string(level),
      "]: ",
      log_msg,
      "\n"
    ]
  end

  defp format_entry(nil) do
    "No entry with that ID exists"
  end

  defp join_entries(elem, {msg, acc, acc_len}) do
    elem_len = IO.iodata_length(elem)

    if elem_len + acc_len > 1950 do
      text = IO.iodata_to_binary(acc)
      Nostrum.Api.create_message!(msg, text)
      {msg, [elem, "\n"], elem_len + 1}
    else
      {msg, [acc, elem, "\n"], acc_len + elem_len + 1}
    end
  end
end
