defmodule Adjutant.PsychoEffects do
  @moduledoc """
  Module that holds all functions used for "troll" effects.
  """
  @random_effects [
    :resolve_role_effect,
    :resolve_timeout_effect,
    :resolve_shadowban_effect,
    :resolve_disconnect_effect,
    :resolve_troll_effect,
    :resolve_react_effect
  ]

  # If the user isn't in a voice channel, disconnect doesn't make sense
  # so don't include it in the list of possible random effects
  @non_special_random_effects @random_effects -- [:resolve_disconnect_effect]

  # If the user is the guild owner, don't include effects that would
  # not work on them. Note: also removing disconnect effect because
  # the ability to do that should be checked before if the user is
  # the guild owner
  @guild_owner_effects @random_effects --
                         [
                           :resolve_disconnect_effect,
                           :resolve_timeout_effect,
                           :resolve_role_effect
                         ]

  @troll_emojis Application.compile_env!(:adjutant, :troll_emojis)

  @primary_guild_id Application.compile_env!(:adjutant, :primary_guild_id)

  @atomic_ref_key {__MODULE__, :psycho_effects_ref}

  alias Nostrum.Api
  alias Nostrum.Snowflake
  alias Nostrum.Struct.{Emoji, Message}

  import Adjutant.Util, only: [admin_msg?: 1, owner_msg?: 1]

  require Logger

  # Slot 1 holds the unix time in seconds
  # of the last time a random effect was resolved
  @last_psycho_effect_time_key 1

  # Slot 2 holds a counter for the number of messages
  # that have been sent since the last effect was resolved
  @last_psycho_effect_counter_key 2

  # Slot 3 holds the id of the user who got the effect
  @last_user_afflicted_key 3

  # Slot 4 holds the enum of the effect for the effected user
  # if the effect is one that happens over time
  @over_time_effect_key 4

  # How big the array needs to be
  @atomic_slot_count 4

  @over_time_effect_none 0
  @over_time_effect_shadowban 1
  @over_time_effect_troll 2
  @over_time_effect_react 3

  @spec maybe_resolve_random_effect(Message.t()) :: :ignore
  def maybe_resolve_random_effect(%Message{} = msg) do
    atomic_ref = get_atomic_ref()

    if should_resolve?(msg, atomic_ref) do
      Logger.info("Resolving random effect")
      resolve_random_effect(msg, atomic_ref)
    end

    :ignore
  end

  @spec should_resolve?(Message.t(), :atomics.atomics_ref()) :: boolean()
  def should_resolve?(%Message{} = msg, ref) do
    Logger.debug("Checking if we should resolve a random effect")

    %{
      guild_id: guild_id,
      author: %{id: user_id},
      member: %{roles: roles},
      channel_id: channel_id
    } = msg

    # admins and owners can always be psychoed
    can_be_psychoed =
      guild_id == @primary_guild_id and
        (Enum.member?(roles, ranger_role_id()) or admin_msg?(msg) or owner_msg?(msg)) and
        Adjutant.PsychoEffects.Channel.psychoable_channel?(channel_id)

    Logger.debug(["User is able to be psychoed: ", inspect(can_be_psychoed)])

    res = can_be_psychoed and :rand.uniform(sliding_probability(user_id, ref)) == 1

    Logger.debug(["Should resolve random effect: ", to_string(res)])

    if res do
      # reset the counter
      :atomics.put(ref, @last_psycho_effect_counter_key, 0)
    end

    res
  rescue
    e ->
      Logger.error(["Error in should_resolve?(): ", Exception.format(:error, e, __STACKTRACE__)])
      false
  end

  @spec maybe_resolve_user_effect(Message.t()) :: any()
  def maybe_resolve_user_effect(%Message{} = msg) do
    ref = get_atomic_ref()

    Logger.debug("Checking if we should resolve a user effect")

    over_time_effect = :atomics.get(ref, @over_time_effect_key)

    if over_time_effect == @over_time_effect_none do
      Logger.debug("No over time effect to resolve, halting")
      throw(:halt)
    end

    Logger.debug("Over time effect key is #{over_time_effect}")

    %{id: message_id, channel_id: channel_id, author: %{id: user_id}} = msg

    last_user = :atomics.get(ref, @last_user_afflicted_key)

    unless last_user == user_id do
      Logger.debug("User is not the last user afflicted, halting")
      throw(:halt)
    end

    last_date_unix_seconds = :atomics.get(ref, @last_psycho_effect_time_key)
    now = System.os_time(:second)

    case over_time_effect do
      @over_time_effect_shadowban when now - last_date_unix_seconds <= 5 * 60 ->
        Logger.debug("Attempting to resolve shadowban effect")

        Task.start(fn -> shadowban(channel_id, message_id) end)

      @over_time_effect_troll when now - last_date_unix_seconds <= 10 * 60 ->
        Logger.debug("Attempting to resolve troll effect")

        Task.start(fn -> troll(channel_id, message_id) end)

      @over_time_effect_react when now - last_date_unix_seconds <= 15 * 60 ->
        Logger.debug("Attempting to resolve react effect")

        Task.start(fn -> react(channel_id, message_id) end)

      _ ->
        # shouldn't resolve anything
        # attempt to set the effect to none to speed up the next check
        Logger.debug("Over time effect expired, attempting to set to none")

        :atomics.compare_exchange(
          ref,
          @over_time_effect_key,
          over_time_effect,
          @over_time_effect_none
        )
    end
  catch
    :halt ->
      :ok
  end

  @spec resolve_random_effect(Message.t(), :atomics.atomics_ref()) :: :ok
  def resolve_random_effect(%Message{} = msg, ref) do
    Logger.debug("Selecting random effect")

    %{
      channel_id: channel_id,
      id: msg_id,
      author: %{id: author_id, username: author_username}
    } = msg

    now = System.os_time(:second)
    effect = select_random_effect(msg)

    Logger.debug("Selected effect: #{effect}")

    effect_enum_val =
      case effect do
        :resolve_shadowban_effect -> @over_time_effect_shadowban
        :resolve_troll_effect -> @over_time_effect_troll
        :resolve_react_effect -> @over_time_effect_react
        _ -> @over_time_effect_none
      end

    :atomics.put(ref, @last_psycho_effect_time_key, now)
    :atomics.put(ref, @last_user_afflicted_key, author_id)
    :atomics.put(ref, @over_time_effect_key, effect_enum_val)

    Logger.debug("Sending message about resolving effect")

    Api.create_message!(channel_id, %{
      content: "Resolve all psycho effects!",
      message_reference: %{
        message_id: msg_id
      }
    })

    Logger.info("Resolving random effect: #{effect} on #{author_username}")

    apply(__MODULE__, effect, [msg, ref])
    :ok
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))

      Api.create_message(
        msg.channel_id,
        "An error has occurred, inform Major\n#{Exception.message(e)}"
      )

      :ok
  end

  defp select_random_effect(msg) do
    %{owner_id: owner_id, voice_states: voice_states} =
      Nostrum.Cache.GuildCache.get!(msg.guild_id)

    is_guild_owner = msg.author.id == owner_id

    is_in_voice_channel =
      Enum.any?(voice_states, fn %{user_id: user_id} -> user_id == msg.author.id end)

    cond do
      is_in_voice_channel ->
        :resolve_disconnect_effect

      is_guild_owner ->
        Enum.random(@guild_owner_effects)

      true ->
        Enum.random(@non_special_random_effects)
    end
  end

  def resolve_role_effect(%Message{} = msg, _ref) do
    roles = Application.get_env(:adjutant, :roles)
    role_ids = Enum.map(roles, fn role -> role.id end)

    Enum.each(role_ids, fn role_id ->
      Api.remove_guild_member_role(
        msg.guild_id,
        msg.author.id,
        role_id,
        "Resolve all psycho effects!"
      )
    end)
  end

  def resolve_timeout_effect(%Message{} = msg, ref) do
    guild_id = msg.guild_id
    user_id = msg.author.id

    muted_until =
      DateTime.utc_now()
      |> DateTime.add(10 * 60)
      |> DateTime.to_iso8601()

    Api.modify_guild_member(
      guild_id,
      user_id,
      %{communication_disabled_until: muted_until},
      "Resolve all psycho effects!"
    )
    |> case do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        :atomics.put(ref, @over_time_effect_key, @over_time_effect_shadowban)
        Logger.info("Failed to mute user: #{inspect(reason)}, shadow banning instead")
    end
  end

  # This is a no-op since this is an async effect
  def resolve_shadowban_effect(_msg, _ref) do
    :ok
  end

  # This is a no-op since this is an async effect
  def resolve_troll_effect(_msg, _ref) do
    :ok
  end

  # This is a no-op since this is an async effect
  def resolve_react_effect(_msg, _ref) do
    :ok
  end

  def resolve_disconnect_effect(%Message{} = msg, _ref) do
    voice_states = Nostrum.Cache.GuildCache.get!(msg.guild_id).voice_states

    Enum.reduce(voice_states, :gen_statem.reqids_new(), fn %{user_id: user_id}, acc ->
      req_map = %{
        method: :patch,
        route: Nostrum.Constants.guild_member(msg.guild_id, user_id),
        body: %{
          channel_id: nil
        },
        params: [],
        headers: [
          {"x-audit-log-reason", "Resolve all psycho effects!"},
          {"content-type", "application/json"}
        ]
      }

      req = :gen_statem.send_request(Nostrum.Api.Ratelimiter, {:queue, req_map})
      :gen_statem.reqids_add(req, "Disconnect #{user_id}", acc)
    end)
    |> await_api_responses()
  end

  def shadowban(channel_id, message_id) do
    Api.delete_message(channel_id, message_id)
  end

  def troll(channel_id, message_id) do
    if :rand.uniform(2) == 1 do
      troll_msg = Adjutant.PsychoEffects.Insults.get_random()

      Api.create_message(channel_id, %{
        content: troll_msg.insult,
        message_reference: %{
          message_id: message_id
        }
      })
    end
  end

  def react(channel_id, message_id) do
    requests =
      Enum.map(@troll_emojis, &map_emojis(channel_id, message_id, &1))
      |> Enum.shuffle()
      |> Enum.reduce(:gen_statem.reqids_new(), fn req_map, acc ->
        req = :gen_statem.send_request(Nostrum.Api.Ratelimiter, {:queue, req_map})
        :gen_statem.reqids_add(req, req_map.route, acc)
      end)

    await_api_responses(requests)
  end

  defp await_api_responses(request_list) do
    :gen_statem.wait_response(request_list, :infinity, true)
    |> case do
      {{:reply, resp}, label, new_list} ->
        Logger.info("Got response: #{inspect(resp)} for request: #{inspect(label)}")
        await_api_responses(new_list)

      {{:error, {reason, _s_ref}}, label, new_list} ->
        Logger.error("Got error: #{inspect(reason)} for request: #{inspect(label)}")
        await_api_responses(new_list)

      :no_request ->
        Logger.info("No more requests")
        :ok
    end
  end

  defp map_emojis(channel_id, message_id, emoji) do
    # gonna abuse the fact that we know the inner workings of nostrum here

    emoji =
      case emoji do
        {name, id} ->
          Emoji.api_name(%Emoji{
            name: name,
            id: id
          })

        {name, id, animated} ->
          Emoji.api_name(%Emoji{
            name: name,
            id: id,
            animated: animated
          })

        emoji when is_binary(emoji) ->
          emoji
      end

    route = Nostrum.Constants.channel_reaction_me(channel_id, message_id, emoji)

    %{
      method: :put,
      route: route,
      body: "",
      params: [],
      headers: [{"content-type", "application/json"}]
    }
  end

  @spec sliding_probability(Snowflake.t(), :atomics.atomics_ref()) :: non_neg_integer()
  defp sliding_probability(author_id, ref) do
    Logger.debug("Checking if #{author_id} has been psycho'd recently")

    now = System.os_time(:second)

    last_date_unix_seconds =
      :atomics.get(ref, @last_psycho_effect_time_key)
      |> case do
        0 ->
          Logger.debug("Last psycho effect time was 0, setting to an hour ago")

          assumed_default = now - 60 * 60
          :atomics.compare_exchange(ref, @last_psycho_effect_time_key, 0, assumed_default)
          assumed_default

        val ->
          val
      end

    Logger.debug("Last psycho effect time in unix seconds: #{last_date_unix_seconds}")

    last_user = :atomics.get(ref, @last_user_afflicted_key)

    Logger.debug("Last user afflicted: #{last_user}")

    counter = :atomics.add_get(ref, @last_psycho_effect_counter_key, 1)

    Logger.debug("Counter: #{counter}")

    probability =
      cond do
        # author is the same as last user and it's been less than 2 hours
        author_id == last_user and last_date_unix_seconds + 60 * 60 * 2 >= now ->
          500_000 - counter + :rand.uniform(42)

        # its been less than 20 minutes
        last_date_unix_seconds + 60 * 20 >= now ->
          300_000 - counter + :rand.uniform(42)

        true ->
          diff = now - last_date_unix_seconds
          # number of seconds in three days less the difference
          # since the last psycho effect
          # minimum of 100 - random number between 1 and 42 + 1

          max(60 * 60 * 24 * 3 - diff, 100 - :rand.uniform(42) + 1)
      end

    Logger.debug("Determined probability: 1 in #{probability}")
    probability
  end

  defp get_atomic_ref do
    case :persistent_term.get(@atomic_ref_key, nil) do
      nil ->
        Logger.debug("Creating new atomic ref")
        ref = :atomics.new(@atomic_slot_count, signed: false)
        :persistent_term.put(@atomic_ref_key, ref)
        ref

      ref ->
        ref
    end
  end

  defp ranger_role_id do
    Application.get_env(:adjutant, :ranger_role_id)
  end
end
