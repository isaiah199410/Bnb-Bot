defmodule Adjutant.Library.Shared do
  @moduledoc """
  This module contains shared functions and types for the Adjutant library.
  """

  @type element ::
          :fire
          | :aqua
          | :elec
          | :wood
          | :wind
          | :sword
          | :break
          | :cursor
          | :recov
          | :invis
          | :object
          | :null

  @type skill ::
          :per
          | :inf
          | :tch
          | :str
          | :agi
          | :end
          | :chm
          | :vlr
          | :aff

  @type range ::
          :var
          | :far
          | :near
          | :close
          | :self

  @type dice :: %{
          dienum: pos_integer(),
          dietype: pos_integer()
        }

  @type blight :: %{
          elem: element,
          dmg: dice,
          duration: dice
        }

  @type kind :: :burst | :construct | :melee | :projectile | :wave | :recovery | :summon | :trap

  # credo:disable-for-lines:15 Credo.Check.Refactor.CyclomaticComplexity
  @spec element_to_string(element) :: String.t()
  def element_to_string(element) do
    case element do
      :fire -> "Fire"
      :aqua -> "Aqua"
      :elec -> "Elec"
      :wood -> "Wood"
      :wind -> "Wind"
      :sword -> "Sword"
      :break -> "Break"
      :cursor -> "Cursor"
      :recov -> "Recov"
      :invis -> "Invis"
      :object -> "Object"
      :null -> "Null"
    end
  end

  @spec skill_to_atom(String.t()) :: skill | nil
  def skill_to_atom(skill) do
    skill = String.downcase(skill, :ascii)

    case skill do
      "per" -> :per
      "inf" -> :inf
      "tch" -> :tch
      "str" -> :str
      "agi" -> :agi
      "end" -> :end
      "chm" -> :chm
      "vlr" -> :vlr
      "aff" -> :aff
      "none" -> nil
    end
  end

  @spec skill_to_string(skill() | nil) :: String.t()
  def skill_to_string(skill) do
    case skill do
      :per -> "Perception"
      :inf -> "Info"
      :tch -> "Tech"
      :str -> "Strength"
      :agi -> "Agility"
      :end -> "Endurance"
      :chm -> "Charm"
      :vlr -> "Valor"
      :aff -> "Affinity"
      nil -> "None"
    end
  end

  @spec dice_to_io_list(nil | dice(), iodata()) :: iolist()
  def dice_to_io_list(dice, last \\ "")

  def dice_to_io_list(nil, _last) do
    ["--"]
  end

  def dice_to_io_list(%{dienum: dienum, dietype: 1}, last) do
    [
      to_string(dienum),
      last
    ]
  end

  def dice_to_io_list(%{dienum: dienum, dietype: dietype}, last) do
    [
      to_string(dienum),
      "d",
      to_string(dietype),
      last
    ]
  end

  @spec blight_to_io_list(blight() | nil, iodata()) :: iolist()
  def blight_to_io_list(blight, last \\ "")

  def blight_to_io_list(nil, _last) do
    []
  end

  def blight_to_io_list(%{elem: elem, dmg: dmg, duration: duration}, last) do
    [
      "Blight (",
      to_string(elem) |> String.capitalize(:ascii),
      "): ",
      dice_to_io_list(dmg, " damage"),
      " for ",
      dice_to_io_list(duration, " rounds"),
      last
    ]
  end

  # credo:disable-for-lines:10 Credo.Check.Refactor.CyclomaticComplexity
  @spec skill_to_sort_pos(skill()) :: pos_integer()
  def skill_to_sort_pos(skill) do
    case skill do
      :per -> 0
      :inf -> 1
      :tch -> 2
      :str -> 3
      :agi -> 4
      :end -> 5
      :chm -> 6
      :vlr -> 7
      :aff -> 8
    end
  end

  @spec gen_suggestions(map() | [map()], String.t(), float()) :: [{float(), map()}]
  def gen_suggestions(map, name, min_dist) when is_map(map),
    do: gen_suggestions(Map.to_list(map), name, min_dist)

  def gen_suggestions(list, name, min_dist) when is_list(list) do
    lower_name = String.downcase(name, :ascii)

    list
    |> Stream.map(fn {key, value} -> {String.jaro_distance(key, lower_name), value} end)
    |> Stream.filter(fn {dist, _} -> dist >= min_dist end)
    |> Enum.sort_by(fn {d, _} -> d end, &>=/2)
    |> Enum.take(25)
  end

  @spec gen_autocomplete(map() | [map()], String.t(), float()) :: [{float(), String.t()}]
  def gen_autocomplete(map, to_search, min_dist) when is_map(map),
    do: gen_autocomplete(Map.to_list(map), to_search, min_dist)

  def gen_autocomplete(list, to_search, min_dist) when is_list(list) do
    lower_name = String.downcase(to_search, :ascii)

    list
    |> Stream.map(fn {key, value} -> {String.jaro_distance(key, lower_name), value.name} end)
    |> Stream.filter(fn {dist, _} -> dist >= min_dist end)
    |> Enum.sort_by(fn {d, _} -> d end, &>=/2)
    |> Enum.take(25)
  end

  @spec return_autocomplete(GenServer.from(), [{String.t(), String.t()}], String.t(), float()) ::
          :ok
  def return_autocomplete(from, list, to_search, min_dist) do
    to_search = String.downcase(to_search, :ascii)

    res =
      list
      |> Stream.map(fn {lower, upper} -> {String.jaro_distance(lower, to_search), upper} end)
      |> Stream.filter(fn {dist, _} -> dist >= min_dist end)
      |> Enum.sort_by(fn {d, _} -> d end, &>=/2)
      |> Enum.take(25)

    GenServer.reply(from, res)
  end
end
