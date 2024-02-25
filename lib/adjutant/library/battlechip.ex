defmodule Adjutant.Library.Battlechip do
  @moduledoc """
  Defines the BattleChip struct, and functions for interacting with them.
  """
  require Logger

  alias Adjutant.Library.Shared
  alias Adjutant.Library.Shared.Blight
  alias Adjutant.Library.Shared.Dice

  use Ecto.Schema
  import Ecto.Query
  import Adjutant.Repo.CustomQuery

  @type class :: :standard | :mega | :giga

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          cr: non_neg_integer(),
          elem: [Shared.element()],
          skill: [Shared.skill()],
          range: Shared.range(),
          hits: String.t(),
          targets: String.t(),
          description: String.t(),
          effect: [String.t()] | nil,
          effduration: non_neg_integer() | nil,
          blight: Shared.blight() | nil,
          damage: Shared.dice() | nil,
          kind: Shared.kind(),
          class: class()
        }

  @derive [Inspect]
  schema "Battlechip" do
    field :name, :string

    field :elem, {:array, Ecto.Enum},
      values: [
        fire: "Fire",
        aqua: "Aqua",
        elec: "Elec",
        wood: "Wood",
        wind: "Wind",
        sword: "Sword",
        break: "Break",
        cursor: "Cursor",
        recov: "Recov",
        invis: "Invis",
        object: "Object",
        null: "Null"
      ]

    field :skill, {:array, Ecto.Enum},
      values: [
        per: "PER",
        inf: "INF",
        tch: "TCH",
        str: "STR",
        agi: "AGI",
        end: "END",
        chm: "CHM",
        vlr: "VLR",
        aff: "AFF"
      ]

    field :range, Ecto.Enum,
      values: [var: "Varies", self: "Self", close: "Close", near: "Near", far: "Far"]

    field :hits, :string
    field :targets, :string
    field :description, :string

    field :effect, {:array, Ecto.Enum},
      values: [
        :Stagger,
        :Blind,
        :Confuse,
        :Lock,
        :Shield,
        :Barrier,
        :"AC Pierce",
        :"AC Down",
        :Weakness,
        :Aura,
        :Invisible,
        :Paralysis,
        :Panic,
        :Heal,
        :"Dmg Boost",
        :Move
      ]

    field :effduration, :integer
    field :blight, Blight
    field :damage, Dice

    field :kind, Ecto.Enum,
      values: [
        melee: "Melee",
        projectile: "Projectile",
        wave: "Wave",
        burst: "Burst",
        summon: "Summon",
        construct: "Construct",
        support: "Support",
        heal: "Heal",
        trap: "Trap"
      ]

    field :class, Ecto.Enum,
      values: [standard: "Standard", mega: "Mega", giga: "Giga"],
      default: :standard

    field :custom, :boolean, default: false

    field :cr, :integer, default: 0

    field :median_hits, :float, default: 1.0
    field :median_targets, :float, default: 1.0
  end

  def avg_dmg(%__MODULE__{damage: nil}) do
    0
  end

  def avg_dmg(%__MODULE__{damage: dice}) do
    floor(dice.dienum * (dice.dietype / 2 + 0.5))
  end

  @spec load_chips :: :ok | {:error, String.t()}
  def load_chips do
    :ok
  end

  @spec get_chip_ct() :: non_neg_integer()
  def get_chip_ct do
    Adjutant.Repo.Postgres.aggregate(__MODULE__, :count)
  end

  @spec get(String.t()) :: Adjutant.Library.Battlechip.t() | nil
  def get(name) do
    query = from(c in __MODULE__, where: c.name == ^name)
    Adjutant.Repo.Postgres.one(query)
  end

  @spec get!(String.t()) :: Adjutant.Library.Battlechip.t() | no_return()
  def get!(name) do
    query = from(c in __MODULE__, where: c.name == ^name)
    Adjutant.Repo.Postgres.one!(query)
  end

  @spec get_autocomplete(String.t(), float()) :: [{float(), String.t()}]
  def get_autocomplete(name, min_dist \\ 0.2) when min_dist >= 0.0 and min_dist <= 1.0 do
    query =
      from(c in __MODULE__,
        where: word_similarity(c.name, ^name) >= ^min_dist,
        limit: 10,
        order_by: [
          fragment("word_similarity(?, ?) DESC", c.name, ^name),
          asc: c.name
        ]
      )

    Adjutant.Repo.Postgres.all(query) |> Enum.map(fn chip -> chip.name end)
  end

  @spec exists?(String.t()) :: boolean()
  def exists?(name) do
    query = from(c in __MODULE__, where: c.name == ^name)
    Adjutant.Repo.Postgres.exists?(query)
  end

  @spec run_chip_filter(keyword()) :: [Adjutant.Library.Battlechip.t()]
  def run_chip_filter(args) do
    skill = args[:skill]
    elem = args[:element]
    range = args[:range]
    kind = args[:kind]
    class = args[:class]
    cr = args[:cr]
    min_cr = args[:min_cr]
    max_cr = args[:max_cr]
    min_avg_dmg = args[:min_avg_dmg]
    max_avg_dmg = args[:max_avg_dmg]
    blight = args[:blight]

    query =
      skill_filter(true, skill)
      |> element_filter(elem)
      |> range_filter(range)
      |> kind_filter(kind)
      |> class_filter(class)
      |> cr_filter(cr)
      |> min_cr_filter(min_cr)
      |> max_cr_filter(max_cr)
      |> min_avg_damage_filter(min_avg_dmg)
      |> max_avg_damage_filter(max_avg_dmg)
      |> blight_filter(blight)

    query = from c in __MODULE__, where: ^query
    Adjutant.Repo.Postgres.all(query)

    # GenServer.call(:chip_table, {:filter, args})
  end

  @spec effect_to_io_list(Adjutant.Library.Battlechip.t()) :: iolist()
  def effect_to_io_list(%{effect: nil, effduration: nil}) do
    []
  end

  def effect_to_io_list(%{effect: effect, effduration: effduration})
      when is_nil(effduration) or effduration == 0 do
    eff_list = Enum.intersperse(effect, ", ")
    ["Effect: ", eff_list]
  end

  def effect_to_io_list(%{effect: effect, effduration: effduration}) do
    eff_list = Enum.intersperse(effect, ", ")

    [
      "Effect: ",
      eff_list,
      " for up to ",
      to_string(effduration),
      " round(s)"
    ]
  end

  defimpl Adjutant.Library.LibObj do
    alias Nostrum.Struct.Component.Button

    @chip_emoji Application.compile_env!(:adjutant, :chip_emoji)

    def type(_value), do: :chip

    @spec to_btn(Adjutant.Library.Battlechip.t(), boolean()) :: Button.t()
    def to_btn(chip, disabled \\ false) do
      lower_name = "c_#{chip.name}"

      Button.interaction_button(chip.name, lower_name,
        style: 2,
        emoji: @chip_emoji,
        disabled: disabled
      )
    end

    @spec to_btn_with_uuid(Adjutant.Library.Battlechip.t(), boolean(), 0..0xFF_FF_FF) ::
            Button.t()
    def to_btn_with_uuid(chip, disabled \\ false, uuid) when uuid in 0..0xFF_FF_FF do
      uuid_str = Integer.to_string(uuid, 16) |> String.pad_leading(6, "0")
      lower_name = "#{uuid_str}_c_#{chip.name}"

      Button.interaction_button(chip.name, lower_name,
        style: 2,
        emoji: @chip_emoji,
        disabled: disabled
      )
    end

    @spec to_persistent_btn(Adjutant.Library.Battlechip.t(), boolean()) :: Button.t()
    def to_persistent_btn(chip, disabled \\ false) do
      lower_name = "cr_#{chip.name}"

      Button.interaction_button(chip.name, lower_name,
        style: 2,
        emoji: @chip_emoji,
        disabled: disabled
      )
    end
  end

  defimpl String.Chars do
    def to_string(%Adjutant.Library.Battlechip{} = chip) do
      elems = [
        Stream.map(chip.elem, fn elem -> Adjutant.Library.Shared.element_to_string(elem) end)
        |> Enum.intersperse(", "),
        " | "
      ]

      skill =
        if is_nil(chip.skill) do
          []
        else
          [String.upcase(Enum.join(chip.skill, ", "), :ascii), " | "]
        end

      range = [String.capitalize(Kernel.to_string(chip.range), :ascii), " | "]
      kind = String.capitalize(Kernel.to_string(chip.kind), :ascii)

      hits = hits_to_io_list(chip)

      targets = targets_to_io_list(chip)

      damage =
        if is_nil(chip.damage) do
          []
        else
          [Adjutant.Library.Shared.dice_to_io_list(chip.damage, " damage"), " | "]
        end

      class =
        if chip.class == :standard do
          []
        else
          [" | ", String.capitalize(Kernel.to_string(chip.class), :ascii)]
        end

      cr =
        if chip.cr > 0 and chip.class == :standard do
          [" | CR ", Integer.to_string(chip.cr)]
        else
          []
        end

      io_list = [
        "```\n",
        chip.name,
        " - ",
        elems,
        skill,
        range,
        damage,
        hits,
        targets,
        kind,
        class,
        cr,
        "\n\n",
        chip.description,
        "\n```"
      ]

      IO.chardata_to_string(io_list)
    end

    defp hits_to_io_list(%Adjutant.Library.Battlechip{hits: nil}) do
      []
    end

    defp hits_to_io_list(%Adjutant.Library.Battlechip{hits: "1"}) do
      ["1 hit", " | "]
    end

    defp hits_to_io_list(%Adjutant.Library.Battlechip{hits: hits}) do
      [hits, " hits | "]
    end

    defp targets_to_io_list(%Adjutant.Library.Battlechip{targets: nil}) do
      []
    end

    defp targets_to_io_list(%Adjutant.Library.Battlechip{targets: "1"}) do
      ["1 target", " | "]
    end

    defp targets_to_io_list(%Adjutant.Library.Battlechip{targets: targets}) do
      [targets, " targets | "]
    end
  end

  defp skill_filter(acc, nil), do: acc
  defp skill_filter(acc, :none), do: dynamic([c], is_nil(c.skill) and ^acc)
  defp skill_filter(acc, skill), do: dynamic([c], array_contains(c.skill, ^skill) and ^acc)

  defp element_filter(acc, nil), do: acc
  defp element_filter(acc, element), do: dynamic([c], array_contains(c.elem, ^element) and ^acc)

  defp range_filter(acc, nil), do: acc
  defp range_filter(acc, range), do: dynamic([c], c.range == ^range and ^acc)

  defp kind_filter(acc, nil), do: acc
  defp kind_filter(acc, kind), do: dynamic([c], c.kind == ^kind and ^acc)

  defp class_filter(acc, nil), do: acc
  defp class_filter(acc, class), do: dynamic([c], c.class == ^class and ^acc)

  defp cr_filter(acc, nil), do: acc
  defp cr_filter(acc, cr), do: dynamic([c], c.cr == ^cr and ^acc)

  defp min_cr_filter(acc, nil), do: acc
  defp min_cr_filter(acc, cr), do: dynamic([c], c.cr >= ^cr and ^acc)

  defp max_cr_filter(acc, nil), do: acc
  defp max_cr_filter(acc, cr), do: dynamic([c], c.cr <= ^cr and ^acc)

  defp blight_filter(acc, nil), do: acc
  defp blight_filter(acc, :null), do: dynamic([c], is_nil(c.blight) and ^acc)

  defp blight_filter(acc, blight),
    do: dynamic([c], blight_elem_access(c.blight) == ^blight and ^acc)

  defp min_avg_damage_filter(acc, nil), do: acc

  defp min_avg_damage_filter(acc, dmg),
    do: dynamic([c], die_average(c.damage) >= ^dmg and ^acc)

  defp max_avg_damage_filter(acc, nil), do: acc

  defp max_avg_damage_filter(acc, dmg),
    do: dynamic([c], die_average(c.damage) <= ^dmg and ^acc)
end
