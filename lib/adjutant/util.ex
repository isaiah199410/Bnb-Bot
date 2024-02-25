defmodule Adjutant.Util do
  @moduledoc """
  Various internal utility functions
  """

  alias Nostrum.Api
  alias Nostrum.Struct.Interaction
  alias Nostrum.Struct.Message
  import Nostrum.Snowflake, only: [is_snowflake: 1]
  require Logger

  @owner_id Application.compile_env!(:adjutant, :owner_id)
  @admins Application.compile_env!(:adjutant, :admins)

  @doc """
  React to a message with a given unicode emoji, if a boolean is given instead
  then it will react with thumbs up or down
  """
  @spec react(Message.t(), boolean | String.t()) :: any()
  def react(msg, emote \\ "\u{1F44D}")

  def react(%Message{channel_id: channel_id, id: msg_id}, true) do
    Logger.debug("Reacting with \u{2705}")
    Api.create_reaction(channel_id, msg_id, "\u{2705}")
  end

  def react(%Message{channel_id: channel_id, id: msg_id}, false) do
    Logger.debug("Reacting with \u{274E}")
    Api.create_reaction(channel_id, msg_id, "\u{274E}")
  end

  def react(%Message{channel_id: channel_id, id: msg_id}, emote) do
    Logger.debug("Reacting with #{emote}")
    Api.create_reaction(channel_id, msg_id, emote)
  end

  @doc """
  Check if a message is from the owner or an admin
  """
  @spec get_user_perms(Message.t() | Interaction.t()) ::
          :admin | :everyone | :owner
  def get_user_perms(msg) do
    cond do
      owner_msg?(msg) -> :owner
      admin_msg?(msg) -> :admin
      true -> :everyone
    end
  end

  @doc """
  Check if a message or interaction is from the owner
  """
  @spec owner_msg?(Message.t() | Interaction.t()) :: boolean
  def owner_msg?(%Message{} = msg) do
    owner_id = Nostrum.Snowflake.cast!(@owner_id)
    msg_author_id = Nostrum.Snowflake.cast!(msg.author.id)
    owner_id == msg_author_id
  end

  def owner_msg?(%Interaction{} = inter) do
    owner_id = Nostrum.Snowflake.cast!(@owner_id)

    inter_author_id =
      if is_nil(inter.member) do
        inter.user.id
      else
        inter.member.user_id
      end
      |> Nostrum.Snowflake.cast!()

    owner_id == inter_author_id
  end

  @doc """
  Check if a message or interaction is from an admin
  """
  @spec admin_msg?(Message.t() | Interaction.t()) :: boolean
  def admin_msg?(%Message{} = msg) do
    Enum.any?(@admins, fn id -> id == msg.author.id end)
  end

  def admin_msg?(%Interaction{} = inter) do
    inter_author_id =
      if is_nil(inter.member) do
        inter.user.id
      else
        inter.member.user_id
      end
      |> Nostrum.Snowflake.cast!()

    Enum.any?(@admins, fn id -> id == inter_author_id end)
  end

  @doc """
  Send a DM to the owner, second argument is for if this should override a do not DM setting
  """
  @spec dm_owner(keyword() | map() | String.t(), boolean()) ::
          {:ok, Message.t()} | :error | nil
  def dm_owner(to_say, override \\ false) do
    res =
      case :persistent_term.get({:bnb_bot_data, :dm_owner}, nil) do
        nil -> true
        val when is_boolean(val) -> val
      end

    if res or override do
      owner_id = @owner_id |> Nostrum.Snowflake.cast!()

      dm_channel_id = find_dm_channel_id(owner_id)
      Api.create_message(dm_channel_id, to_say)
    end
  end

  @doc """
  Finds the id of a the DM channel for a user, or fetches it from the API if its not in the cache
  """
  @spec find_dm_channel_id(Nostrum.Snowflake.t()) :: Nostrum.Snowflake.t()
  def find_dm_channel_id(user_id) when is_snowflake(user_id) do
    # get the channel_id where it's first recipient's.id == user_id
    dm_channel_list =
      :ets.select(
        :nostrum_channels,
        [{{:"$1", %{recipients: [%{id: :"$2"}]}}, [{:==, :"$2", user_id}], [:"$1"]}]
      )

    case dm_channel_list do
      [id | _] ->
        id

      _ ->
        channel = Api.create_dm!(user_id)
        channel.id
    end
  end

  def slash_args_to_map([%{type: 1, name: name, options: options}]) do
    opts = slash_args_to_map(options)
    {name, opts}
  end

  def slash_args_to_map(options) do
    for %{name: name, value: value} <- options, into: %{} do
      {name, value}
    end
  end
end
