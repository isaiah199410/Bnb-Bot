defmodule Adjutant.Repo.Postgres do
  @moduledoc """
  The postgres repo.
  """
  use Ecto.Repo, otp_app: :adjutant, adapter: Ecto.Adapters.Postgres, read_only: true
end
