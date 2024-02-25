defmodule Adjutant.Repo.Migrations.LogDb do
  use Ecto.Migration

  def change do
    create table("bot_log") do
      add :level, :string #Ecto.Enum, values: [:debug, :info, :notice, :warning, :error, :critical, :alert, :emergency]
      add :message, :text
      timestamps(updated_at: false)
    end
  end
end
