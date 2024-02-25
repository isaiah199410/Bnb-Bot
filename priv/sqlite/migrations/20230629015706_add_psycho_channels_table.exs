defmodule Adjutant.Repo.SQLite.Migrations.AddPsychoChannelsTable do
  use Ecto.Migration

  def change do
    create table("psycho_effect_channel") do
      add :guild_id, :integer, null: false
      add :set_by, :integer, null: false
      timestamps()
    end
  end
end
