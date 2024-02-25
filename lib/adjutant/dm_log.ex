defmodule Adjutant.DmLogger do
  @moduledoc """
  Used to log DMs from anyone except for the owner.
  """

  require Logger

  @dm_log_id Application.compile_env!(:adjutant, :dm_log_id)

  def log_dm(%Nostrum.Struct.Message{} = msg) do
    unless Adjutant.Util.owner_msg?(msg) do
      handle_attachment(msg)

      embed = make_embed(msg)

      Nostrum.Api.create_message(@dm_log_id, embeds: [embed])
    end
  end

  defp handle_attachment(%Nostrum.Struct.Message{} = msg) do
    link_regex =
      ~r/(ftp|http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/

    if (msg.content =~ link_regex or not Enum.empty?(msg.attachments)) and
         :rand.uniform(100) == 1 do
      Task.start(fn ->
        Nostrum.Api.create_message(msg.channel_id, "I ain't clicking that shit")
      end)
    end
  end

  defp make_embed(%Nostrum.Struct.Message{} = msg) do
    base_embed = %Nostrum.Struct.Embed{
      description: "Direct Message Recieved",
      thumbnail: %Nostrum.Struct.Embed.Thumbnail{
        url: Nostrum.Struct.User.avatar_url(msg.author)
      },
      color: 431_948,
      fields: [
        %Nostrum.Struct.Embed.Field{name: "DM From:", value: msg.author.username}
      ]
    }

    content_len = String.length(msg.content)

    embed =
      cond do
        content_len == 0 ->
          Nostrum.Struct.Embed.put_field(base_embed, "Content", "No Message Content")

        # %Nostrum.Struct.Embed.Field{name: "Content", value: "No Message Content"}
        content_len > 1000 ->
          {part_1, part_2} = String.split_at(msg.content, 1000)

          base_embed
          |> Nostrum.Struct.Embed.put_field("Content 1/2", part_1)
          |> Nostrum.Struct.Embed.put_field("Content 2/2", part_2)

        true ->
          Nostrum.Struct.Embed.put_field(base_embed, "Content", msg.content)
      end

    timestamp =
      msg.id
      |> Nostrum.Snowflake.creation_time()
      |> DateTime.to_unix()

    embed = Nostrum.Struct.Embed.put_field(embed, "Time", "<t:#{timestamp}>")

    Enum.reduce(msg.attachments, embed, fn atch, embed ->
      text = "filename:\n#{atch.filename}\nURL:\n#{atch.url}"
      Nostrum.Struct.Embed.put_field(embed, "Attachment", text)
    end)
  end
end
