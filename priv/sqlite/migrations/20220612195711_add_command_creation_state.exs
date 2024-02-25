defmodule Adjutant.Repo.SQLite.Migrations.AddCommandCreationState do
  use Ecto.Migration

  def change do
    create table("created_commands", primary_key: false) do
      add :name, :string, null: false, primary_key: true
      # Will hold the command's create map and scope as EETF
      add :state, :binary, null: false
      timestamps()
    end
  end
end
