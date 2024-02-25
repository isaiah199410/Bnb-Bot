defmodule Adjutant.Command.Slash.AddToBans do
  @moduledoc """
  One of the "hidden" commands. Used to add a member to the list of who would be banned.
  """

  require Logger
  alias Nostrum.Api
  alias Nostrum.Struct.ApplicationCommandInteractionDataOption, as: Option
  use Ecto.Schema
  import Ecto.Query, only: [from: 2]

  @type t :: %__MODULE__{
          added_by: Nostrum.Snowflake.t(),
          to_ban: Nostrum.Snowflake.t(),
          inserted_at: NaiveDateTime.t()
        }

  schema "banlist" do
    field(:added_by, :integer)
    field(:to_ban, :integer)
    timestamps(updated_at: false)
  end

  @spec add_to_bans(Nostrum.Struct.Interaction.t(), [Option.t()]) :: any()
  def add_to_bans(inter, [%Option{value: to_add}]) do
    if Adjutant.Util.owner_msg?(inter) or Adjutant.Util.admin_msg?(inter) do
      add_id_to_list(inter, inter.member.user_id, to_add)
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end

  def list_bans(inter) do
    if Adjutant.Util.owner_msg?(inter) or Adjutant.Util.admin_msg?(inter) do
      send_id_list(inter)
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end

  def salt_the_earth(inter) do
    if Adjutant.Util.owner_msg?(inter) or Adjutant.Util.admin_msg?(inter) do
      if Adjutant.ButtonAwait.get_confirmation?(inter, "Are you sure you want to salt the earth?") do
        salt_the_earth_inner(inter)
      end
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end

  defp salt_the_earth_inner(inter) do
    guild_id = inter.guild_id

    tasks =
      Adjutant.Repo.SQLite.all(__MODULE__)
      |> Enum.map(fn row ->
        Task.async(Api, :create_guild_ban, [guild_id, row.to_ban, 0, "Salting the Earth"])
      end)

    route = "/webhooks/#{inter.application_id}/#{inter.token}"

    msg_task =
      Task.async(fn ->
        Api.request(:post, route, %{
          content: "DEUS VULT! DEUS VULT! DEUS VULT!"
        })
      end)

    Task.await_many([msg_task | tasks], :infinity)

    route = "/webhooks/#{inter.application_id}/#{inter.token}"

    Api.request(:post, route, %{
      content:
        "A time to love and a time to hate; A time for war and a time for peace. - Ecclesiastes 3:8"
    })
  end

  defp send_id_list(inter) do
    list =
      from(u in __MODULE__, select: u.to_ban)
      |> Adjutant.Repo.SQLite.all()
      |> Enum.map(fn to_ban ->
        "<@#{to_ban}>\n"
      end)

    list = ["These users would be banned when you salt the earth\n" | list]

    content = IO.iodata_to_binary(list)

    Api.create_interaction_response(inter, %{
      type: 4,
      data: %{
        content: content,
        flags: 64
      }
    })
  end

  defp add_id_to_list(inter, author_id, to_add) do
    author_id = Nostrum.Snowflake.cast!(author_id)
    to_add = Nostrum.Snowflake.cast!(to_add)

    query = from(u in __MODULE__, where: u.to_ban == ^to_add)

    resp =
      if Adjutant.Repo.SQLite.exists?(query) do
        "That user is already on the list"
      else
        row = %__MODULE__{
          to_ban: to_add,
          added_by: author_id
        }

        Adjutant.Repo.SQLite.insert!(row)

        "Added <@#{to_add}> to the banlist"
      end

    Api.create_interaction_response(inter, %{
      type: 4,
      data: %{
        content: resp,
        flags: 64
      }
    })
  end
end
