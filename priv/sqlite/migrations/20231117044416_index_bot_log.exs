defmodule Adjutant.Repo.SQLite.Migrations.IndexBotLog do
  use Ecto.Migration

  def change do
    create index(:bot_log, [:inserted_at])
  end
end
