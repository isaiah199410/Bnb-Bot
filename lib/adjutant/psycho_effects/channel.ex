defmodule Adjutant.PsychoEffects.Channel do
  @moduledoc """
  Defines the schema for which channels a user can trigger
  the phrase "resolve all psycho effects" in.
  """

  use Ecto.Schema

  require Logger

  import Ecto.Query

  # has implicit :id field
  # which will be the id of a channel
  # in which this cannot be triggered
  schema "psycho_effect_channel" do
    field :guild_id, :integer
    field :set_by, :integer
    timestamps()
  end

  def deny_channel(args) do
    Ecto.Changeset.cast(
      %__MODULE__{},
      args,
      [:id, :guild_id, :set_by]
    )
    |> Ecto.Changeset.validate_required([:guild_id, :set_by])
    |> Adjutant.Repo.SQLite.insert(on_conflict: :nothing)
  end

  def allow_channel(channel_id) do
    # channel_ids are unique, so we don't need to worry about guild_id
    from(c in __MODULE__, where: c.id == ^channel_id)
    |> Adjutant.Repo.SQLite.delete_all()
  end

  def psychoable_channel?(channel_id) do
    exists =
      from(
        c in __MODULE__,
        where: c.id == ^channel_id
      )
      |> Adjutant.Repo.SQLite.exists?()

    # if it doesn't exist, it's psychoable
    not exists
  end
end
