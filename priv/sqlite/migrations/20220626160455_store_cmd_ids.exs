defmodule Adjutant.Repo.SQLite.Migrations.StoreCmdIds do
  use Ecto.Migration

  def change do
    alter table("created_commands") do
      add :cmd_ids, :binary
    end
  end
end
