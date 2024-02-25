defmodule Adjutant.Repo.SQLite do
  @moduledoc """
  The sqlite repo.
  """
  use Ecto.Repo, otp_app: :adjutant, adapter: Ecto.Adapters.SQLite3
end
