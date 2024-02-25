defmodule Adjutant.Repo.SQLite.Migrations.AddRandomInsultsTable do
  use Ecto.Migration

  def change do
    create table("random_insults") do
      add :insult, :text
      timestamps(updated_at: false)
    end
  end
end
