defmodule Adjutant.Util.KVP do
  @moduledoc """
  Module for handling internal global state.
  Slower than using an ets table, but much more memory efficient
  """

  require Logger
  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: :bnb_bot_data)
  end

  def init(initial_state) when is_map(initial_state) do
    {:ok, initial_state}
  end

  def init(_initial_state) do
    Logger.warning("Initial state is not a map, using empty map")
    {:ok, %{}}
  end

  def handle_cast({:insert, key, value}, state) do
    state = Map.put(state, key, value)
    {:noreply, state}
  end

  def handle_cast({:delete, key}, state) do
    state = Map.delete(state, key)
    {:noreply, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end
end
