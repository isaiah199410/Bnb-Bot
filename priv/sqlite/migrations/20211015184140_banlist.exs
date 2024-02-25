defmodule Adjutant.Repo.Migrations.Banlist do
  use Ecto.Migration

  def change do
    create table("banlist") do
      add :added_by, :integer, null: false # user id
      add :to_ban, :integer, null: false # user to ban
      timestamps(updated_at: false)
    end
  end
end
