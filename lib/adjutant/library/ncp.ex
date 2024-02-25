defmodule Adjutant.Library.NCP do
  @moduledoc """
  Defines the NaviCust parts struct and functionality on them.
  Also defines methods for fetching them from the GenServer that holds them.
  """
  require Logger

  #  @enforce_keys [:id, :name, :cost, :color, :description, :conflicts]
  #  @derive [Inspect]
  #  defstruct [:id, :name, :cost, :color, :description, :conflicts]

  use Ecto.Schema
  import Ecto.Query
  import Adjutant.Repo.CustomQuery

  @type colors :: :white | :pink | :yellow | :green | :blue | :red | :gray

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          cost: pos_integer(),
          color: colors(),
          conflicts: [String.t()] | nil,
          description: String.t(),
          custom: boolean()
        }

  @derive [Inspect]
  schema "NaviCust" do
    field :name, :string
    field :description, :string
    field :cost, :integer, source: :size

    field :color, Ecto.Enum,
      values: [
        white: "White",
        pink: "Pink",
        yellow: "Yellow",
        green: "Green",
        blue: "Blue",
        red: "Red",
        gray: "Gray"
      ]

    field :conflicts, {:array, :string}

    field :custom, :boolean, default: false
  end

  @spec load_ncps() :: {:ok} | {:error, String.t()}
  def load_ncps do
    # GenServer.call(:ncp_table, :reload, :infinity)
    {:ok}
  end

  @spec get(String.t()) :: Adjutant.Library.NCP.t() | nil
  def get(name) do
    query = from(n in __MODULE__, where: n.name == ^name)
    Adjutant.Repo.Postgres.one(query)

    # GenServer.call(:ncp_table, {:get_or_nil, name})
  end

  @spec get!(String.t()) :: Adjutant.Library.NCP.t() | no_return()
  def get!(name) do
    query = from(n in __MODULE__, where: n.name == ^name)
    Adjutant.Repo.Postgres.one!(query)
  end

  @spec get_autocomplete(String.t(), float()) :: [String.t()]
  def get_autocomplete(name, min_dist \\ 0.2) when min_dist >= 0.0 and min_dist <= 1.0 do
    query =
      from(n in __MODULE__,
        where: word_similarity(n.name, ^name) >= ^min_dist,
        limit: 10,
        order_by: [
          fragment("word_similarity(?, ?) DESC", n.name, ^name),
          asc: n.name
        ]
      )

    Adjutant.Repo.Postgres.all(query) |> Enum.map(fn ncp -> ncp.name end)

    # GenServer.call(:ncp_table, {:autocomplete, name, min_dist})
  end

  @spec get_starters([colors()]) :: [t()]
  def get_starters(colors) do
    query = from(n in __MODULE__, where: n.cost <= 2)

    Adjutant.Repo.Postgres.all(query)
    |> Enum.filter(fn ncp -> ncp.color in colors end)

    # GenServer.call(:ncp_table, {:starters, colors})
  end

  @spec get_ncps_by_color(colors()) :: [t()]
  def get_ncps_by_color(color) do
    query = from(n in __MODULE__, where: n.color == ^color)
    Adjutant.Repo.Postgres.all(query)

    # GenServer.call(:ncp_table, {:color, color})
  end

  @spec get_ncp_ct() :: non_neg_integer()
  def get_ncp_ct do
    Adjutant.Repo.Postgres.aggregate(__MODULE__, :count)
    # GenServer.call(:ncp_table, :len, :infinity)
  end

  @spec validate_conflicts() :: {:ok} | {:error, iodata()}
  def validate_conflicts do
    query = """
    WITH conflicts AS (
    SELECT DISTINCT UNNEST(conflicts) AS conflict FROM "NaviCust"
    )
    SELECT conflict AS name FROM conflicts WHERE conflict NOT IN (SELECT name from "NaviCust")
    """

    result = Adjutant.Repo.Postgres.query!(query)

    rows = Enum.map(result.rows, &Adjutant.Repo.Postgres.load(__MODULE__, {result.columns, &1}))

    if Enum.empty?(rows) do
      {:ok}
    else
      conflicts =
        Enum.map(rows, fn %{name: name} ->
          "NCP conflict #{name} does not exist"
        end)

      {:error, conflicts}
    end

    # GenServer.call(:ncp_table, :validate_conflicts, :infinity)
  end

  @spec ncp_color_to_string(Adjutant.Library.NCP.t()) :: String.t()
  def ncp_color_to_string(ncp) do
    case ncp.color do
      :white -> "White"
      :pink -> "Pink"
      :yellow -> "Yellow"
      :green -> "Green"
      :blue -> "Blue"
      :red -> "Red"
      :gray -> "Gray"
    end
  end

  @spec ncp_color_to_sort_number(Adjutant.Library.NCP.t()) :: non_neg_integer()
  def ncp_color_to_sort_number(ncp) do
    case ncp.color do
      :white -> 0
      :pink -> 1
      :yellow -> 2
      :green -> 3
      :blue -> 4
      :red -> 5
      :gray -> 6
    end
  end

  # credo:disable-for-lines:30 Credo.Check.Refactor.CyclomaticComplexity
  @spec element_to_colors(Adjutant.Library.Shared.element()) :: [colors()]
  def element_to_colors(element) do
    case element do
      :fire ->
        [:white, :pink, :yellow, :blue, :gray]

      :aqua ->
        [:white, :pink, :yellow, :blue, :red]

      :elec ->
        [:white, :pink, :yellow, :green, :blue]

      :wood ->
        [:white, :pink, :yellow, :green, :red]

      :wind ->
        [:white, :pink, :yellow, :blue, :gray]

      :sword ->
        [:white, :pink, :yellow, :green, :red]

      :break ->
        [:white, :pink, :yellow, :green, :red]

      :cursor ->
        [:white, :pink, :yellow, :blue, :gray]

      :recov ->
        [:white, :pink, :yellow, :blue, :red]

      :invis ->
        [:white, :pink, :yellow, :green, :gray]

      :object ->
        [:white, :pink, :yellow, :red, :gray]

      :null ->
        [:white, :pink, :yellow, :green, :blue, :red, :gray]
    end
  end

  @spec locate_by_conflict(String.t()) :: [__MODULE__.t()]
  def locate_by_conflict(conflict) do
    query =
      from(n in __MODULE__,
        where: array_contains(n.conflicts, ^conflict)
      )

    Adjutant.Repo.Postgres.all(query)
  end

  defimpl Adjutant.Library.LibObj do
    alias Nostrum.Struct.Component.Button

    @white_emoji Application.compile_env!(:adjutant, [:ncp_emoji, :white])
    @pink_emoji Application.compile_env!(:adjutant, [:ncp_emoji, :pink])
    @yellow_emoji Application.compile_env!(:adjutant, [:ncp_emoji, :yellow])
    @green_emoji Application.compile_env!(:adjutant, [:ncp_emoji, :green])
    @blue_emoji Application.compile_env!(:adjutant, [:ncp_emoji, :blue])
    @red_emoji Application.compile_env!(:adjutant, [:ncp_emoji, :red])
    @gray_emoji Application.compile_env!(:adjutant, [:ncp_emoji, :gray])

    def type(_value), do: :ncp

    @spec to_btn(Adjutant.Library.NCP.t(), boolean()) :: Button.t()
    def to_btn(ncp, disabled \\ false) do
      lower_name = "n_#{ncp.name}"
      emoji = ncp_color_to_emoji(ncp.color)

      Button.interaction_button(ncp.name, lower_name,
        style: 3,
        emoji: emoji,
        disabled: disabled
      )
    end

    @spec to_btn_with_uuid(Adjutant.Library.NCP.t(), boolean(), 0..0xFF_FF_FF) ::
            Button.t()
    def to_btn_with_uuid(ncp, disabled \\ false, uuid) when uuid in 0..0xFF_FF_FF do
      uuid_str = Integer.to_string(uuid, 16) |> String.pad_leading(6, "0")
      lower_name = "#{uuid_str}_n_#{ncp.name}"
      emoji = ncp_color_to_emoji(ncp.color)

      Button.interaction_button(ncp.name, lower_name,
        style: 3,
        emoji: emoji,
        disabled: disabled
      )
    end

    @spec to_persistent_btn(Adjutant.Library.NCP.t(), boolean()) :: Button.t()
    def to_persistent_btn(ncp, disabled \\ false) do
      lower_name = "nr_#{ncp.name}"
      emoji = ncp_color_to_emoji(ncp.color)

      Button.interaction_button(ncp.name, lower_name,
        style: 3,
        emoji: emoji,
        disabled: disabled
      )
    end

    @spec ncp_color_to_emoji(Adjutant.Library.NCP.colors()) :: map()
    defp ncp_color_to_emoji(color) do
      case color do
        :white -> @white_emoji
        :pink -> @pink_emoji
        :yellow -> @yellow_emoji
        :green -> @green_emoji
        :blue -> @blue_emoji
        :red -> @red_emoji
        :gray -> @gray_emoji
      end
    end
  end

  defimpl String.Chars do
    def to_string(%Adjutant.Library.NCP{} = ncp) do
      # Same as but faster due to how Elixir works
      # "```\n#{ncp.name} - (#{ncp.cost} EB) - #{ncp.color}\n#{ncp.description}\n```"

      conflicts =
        if is_nil(ncp.conflicts) do
          []
        else
          conflict_list = ncp.conflicts |> Enum.intersperse(", ")
          ["\nConflicts: ", conflict_list]
        end

      io_list = [
        "```\n",
        ncp.name,
        " - (",
        Integer.to_string(ncp.cost),
        " EB) - ",
        Adjutant.Library.NCP.ncp_color_to_string(ncp),
        "\n",
        ncp.description,
        conflicts,
        "\n```"
      ]

      IO.chardata_to_string(io_list)
    end
  end
end
