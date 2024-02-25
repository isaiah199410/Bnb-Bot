defmodule Adjutant.Command.State do
  @moduledoc """
  Module for managing the creation state of slash commands
  """

  use Ecto.Schema

  alias Adjutant.Command.Slash.Id, as: CommandId
  alias Adjutant.Repo.SQLite
  alias Nostrum.Api

  import Ecto.Query

  require Logger

  @primary_key false
  schema "created_commands" do
    field :name, :string, primary_key: true
    field :state, :binary
    field :cmd_ids, CommandId
    timestamps()
  end

  @doc false
  def setup_commands(cmd_list) do
    # since placing this in `Adjutant.SlashCommands` causes a circular dependency
    for command <- cmd_list do
      cmd_state = command.get_creation_state()
      {_, cmd_map} = cmd_state
      name = cmd_map[:name]
      res = SQLite.get(__MODULE__, name)

      should_insert =
        case res do
          %__MODULE__{state: state} ->
            :erlang.binary_to_term(state) != cmd_state

          nil ->
            true
        end

      if should_insert do
        Logger.info("inserting command #{name}")
        ids = create_command(cmd_state)

        SQLite.insert!(
          %__MODULE__{name: name, state: :erlang.term_to_binary(cmd_state), cmd_ids: ids},
          on_conflict: {:replace, [:state, :cmd_ids]}
        )
      end
    end
  end

  @doc false
  def delete_commands(cmd_list) do
    for command <- cmd_list do
      {_, cmd_map} = command.get_creation_state()
      name = cmd_map[:name]
      cmd_data = SQLite.get(__MODULE__, name)

      unless is_nil(cmd_data) do
        Logger.info("deleting command #{name}")

        delete_command(cmd_data.cmd_ids)

        from(c in __MODULE__, where: c.name == ^name)
        |> SQLite.delete_all()
      end
    end
  end

  # returns {:global, id} for insertion
  defp create_command({:global, cmd_map}) do
    {:ok, %{id: id}} = Api.create_global_application_command(cmd_map)
    id = Nostrum.Snowflake.cast!(id)
    {:global, id}
  end

  defp create_command({guild_ids, cmd_map}) when is_list(guild_ids) do
    ids =
      Enum.map(guild_ids, fn guild_id ->
        {:ok, %{id: id}} = Api.create_guild_application_command(guild_id, cmd_map)
        id = Nostrum.Snowflake.cast!(id)
        {guild_id, id}
      end)

    {:guild, ids}
  end

  defp create_command({guild_id, cmd_map}) do
    {:ok, %{id: id}} = Api.create_guild_application_command(guild_id, cmd_map)
    id = Nostrum.Snowflake.cast!(id)
    {:guild, [{guild_id, id}]}
  end

  defp delete_command({:global, id}) do
    {:ok} = Api.delete_global_application_command(id)
  end

  defp delete_command({:guild, ids}) do
    for {guild_id, id} <- ids do
      {:ok} = Api.delete_guild_application_command(guild_id, id)
    end
  end
end
