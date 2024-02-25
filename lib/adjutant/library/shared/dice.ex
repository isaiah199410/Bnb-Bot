defmodule Adjutant.Library.Shared.Dice do
  @moduledoc """
  Ecto Type mapping for die rolls.
  """

  @enforce_keys [:dienum, :dietype]
  defstruct [:dienum, :dietype]

  @typedoc """
  Represents a dice roll. DieNum is the number of dice to roll, and DieType is the type of dice to roll.
  """
  @type t :: %__MODULE__{
          dienum: non_neg_integer(),
          dietype: non_neg_integer()
        }

  use Ecto.Type

  def type, do: :dice

  def cast(%__MODULE__{} = dice) do
    {:ok, dice}
  end

  def cast({dienum, dietype}) when is_integer(dienum) and is_integer(dietype) do
    {:ok, %__MODULE__{dienum: dienum, dietype: dietype}}
  end

  def cast(_) do
    :error
  end

  @spec load({integer(), integer()} | nil) :: {:ok, t() | nil} | :error
  def load({num, size}) when is_integer(num) and is_integer(size) do
    die = %__MODULE__{dienum: num, dietype: size}
    {:ok, die}
  end

  def load(nil) do
    {:ok, nil}
  end

  def load(_), do: :error

  @spec dump(t() | nil) :: :error | {:ok, {non_neg_integer(), non_neg_integer()} | nil}
  def dump(%__MODULE__{dienum: dienum, dietype: dietype}) do
    data = {dienum, dietype}
    {:ok, data}
  end

  def dump(nil) do
    {:ok, nil}
  end

  def dump(_), do: :error
end
