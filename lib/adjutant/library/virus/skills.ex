defmodule Adjutant.Library.Virus.Skills do
  @moduledoc """
  Ecto type mapping for a virus's skills.
  """

  @skills [
    # Perception
    :per,
    # Info
    :inf,
    # Tech
    :tch,
    # Strength
    :str,
    # Agility
    :agi,
    # Endurance
    :end,
    # Charm
    :chm,
    # Valor
    :vlr,
    # Affinity
    :aff
  ]

  use Ecto.Type

  defstruct per: 0, inf: 0, tch: 0, str: 0, agi: 0, end: 0, chm: 0, vlr: 0, aff: 0

  def type, do: :virus_skills

  def cast(skills) when is_map(skills) do
    skills =
      Enum.map(skills, fn {key, value} ->
        {convert(key), value}
      end)

    {:ok, struct(__MODULE__, skills)}
  end

  def cast(_skills), do: :error

  def load(skills) when is_map(skills) do
    skills =
      Enum.map(skills, fn {key, value} ->
        {convert(key), value}
      end)

    {:ok, struct(__MODULE__, skills)}
  end

  def load(_skills), do: :error

  def dump(%__MODULE__{} = skills) do
    res =
      Map.from_struct(skills)
      |> Enum.map(fn {key, value} ->
        {to_string(key), value}
      end)
      |> Map.new()

    {:ok, res}
  end

  defp convert(skill) when is_binary(skill) do
    String.downcase(skill, :ascii) |> String.to_existing_atom()
  end

  defp convert(skill) when skill in @skills do
    skill
  end
end
