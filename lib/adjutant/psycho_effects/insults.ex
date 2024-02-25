defmodule Adjutant.PsychoEffects.Insults do
  @moduledoc """
  Defines the troll insults that the bot can use.
  """
  use Ecto.Schema
  import Ecto.Query

  @type t :: %__MODULE__{
          id: integer(),
          insult: String.t(),
          inserted_at: NaiveDateTime.t()
        }

  schema "random_insults" do
    field :insult, :string
    timestamps(updated_at: false)
  end

  @spec add_new!(String.t()) :: __MODULE__.t() | no_return()
  def add_new!(insult) do
    %__MODULE__{insult: insult}
    |> Adjutant.Repo.SQLite.insert!()
  end

  @spec get_by_id(integer()) :: __MODULE__.t() | nil
  def get_by_id(id) do
    Adjutant.Repo.SQLite.get(__MODULE__, id)
  end

  @spec delete(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def delete(insult) do
    Adjutant.Repo.SQLite.delete(insult)
  end

  def get_all do
    Adjutant.Repo.SQLite.all(__MODULE__)
  end

  def update!(insult, new_text) do
    Ecto.Changeset.cast(insult, %{insult: new_text}, [:insult])
    |> Adjutant.Repo.SQLite.update!()
  end

  @doc """
  Returns a random insult.

  Raises if the table is empty.
  """
  @spec get_random() :: __MODULE__.t() | no_return()
  def get_random do
    from(i in __MODULE__,
      limit: 1,
      order_by: fragment("RANDOM()")
    )
    |> Adjutant.Repo.SQLite.one!()
  end
end
