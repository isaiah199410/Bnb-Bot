defmodule Adjutant.Library.Shared.Blight do
  @moduledoc """
  Defines the Blight ecto type
  """

  use Ecto.Type

  alias Adjutant.Library.Shared.{Dice, Element}

  @enforce_keys [:elem, :dmg, :duration]
  defstruct [:elem, :dmg, :duration]

  @type t :: %__MODULE__{
          elem: Element.t(),
          dmg: Dice.t() | nil,
          duration: Dice.t() | nil
        }

  def type, do: :blight

  def cast(%__MODULE__{} = blight) do
    {:ok, blight}
  end

  def cast(nil) do
    {:ok, nil}
  end

  def cast({elem, dmg, duration}) do
    load({elem, dmg, duration})
  end

  def cast(_) do
    :error
  end

  def load({elem, dmg, duration}) do
    with {:ok, elem} <- Element.convert(elem),
         {:ok, dmg} <- Dice.load(dmg),
         {:ok, duration} <- Dice.load(duration) do
      {:ok, %__MODULE__{elem: elem, dmg: dmg, duration: duration}}
    else
      _ -> :error
    end
  end

  def load(nil) do
    {:ok, nil}
  end

  def load(_), do: :error

  def dump(%__MODULE__{} = blight) do
    elem = Atom.to_string(blight.elem) |> String.capitalize(:ascii)

    with {:ok, dmg} <- Dice.dump(blight.dmg),
         {:ok, duration} <- Dice.dump(blight.duration) do
      {:ok, {elem, dmg, duration}}
    else
      _ -> :error
    end
  end

  def dump(nil) do
    {:ok, nil}
  end

  def dump(_), do: :error
end
