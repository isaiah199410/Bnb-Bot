defmodule Adjutant.Library.Virus.Stats do
  @moduledoc """
  Ecto type mapping for a virus's stats.
  """

  use Ecto.Type

  def type, do: :virus_stats

  def cast(%{"mind" => mind, "body" => body, "spirit" => spirit})
      when mind in 1..5 and body in 1..5 and spirit in 1..5 do
    {:ok, %{mind: mind, body: body, spirit: spirit}}
  end

  def cast(_stats), do: :error

  def load(%{"mind" => mind, "body" => body, "spirit" => spirit})
      when mind in 1..5 and body in 1..5 and spirit in 1..5 do
    {:ok, %{mind: mind, body: body, spirit: spirit}}
  end

  def load(_stats), do: :error

  def dump(%{mind: mind, body: body, spirit: spirit})
      when mind in 1..5 and body in 1..5 and spirit in 1..5 do
    {:ok, %{"mind" => mind, "body" => body, "spirit" => spirit}}
  end

  def dump(_stats), do: :error
end
