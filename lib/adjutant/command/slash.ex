defmodule Adjutant.Command.Slash do
  @moduledoc """
  Describes what public functions each slash command module must define.

  All slash commands must implement the callbacks defined here, and may optionally `use`
  this module to define a `call` function that will be called when the command is executed.

  ```elixir
  use Adjutant.Command.Slash, permissions: :everyone
  ```

  When `use`d, the macro expects a `:permissions` option, which defines who can use the command.
  This option expects either a single `:everyone`, `:admin`, or `:owner` value or a list of such values.

  There is also an optional `:scope` argument that can be used to determine the scope of the command
  when it is created.

  Scope can be one of:
  - `:global`: The command is created globally.
  - `Nostrum.Snowflake.t()`: The command is created in only the guild with the given ID.
  - [`Nostrum.Snowflake.t(), ...`]: The command is created in all guilds with the given IDs.

  By default, the command follows the `:default_command_scope` config option.

  this setting in config can either be `:global`, a guild_id or a list of guild_ids

  Note about scope: If you are changing a command's scope from `:global` to a guild, or vice versa,
  you must manually remove the command from the old scope.
  """

  @default_command_scope Application.compile_env!(:adjutant, :default_command_scope)

  defp deprecated_call do
    quote do
      if inter.type == 2 do
        Nostrum.Api.create_followup_message(inter.token, %{
          content: "Note: This is a deprecated command, it may break in the future",
          flags: 64
        })
      end
    end
  end

  defp everyone_perms(deprecated) do
    deprecated_code =
      if deprecated do
        deprecated_call()
      end

    quote do
      @behaviour Adjutant.Command.Slash
      def call(inter) do
        call_slash(inter)
        unquote(deprecated_code)
        :ignore
      end

      defoverridable call: 1
    end
  end

  defp list_perms(deprecated) do
    deprecated_code =
      if deprecated do
        deprecated_call()
      end

    quote do
      @behaviour Adjutant.Command.Slash
      def call(inter) do
        user_perms = Adjutant.Util.get_user_perms(inter)

        if user_perms in [:admin, :owner] do
          call_slash(inter)
          unquote(deprecated_code)
        else
          Nostrum.Api.create_interaction_response(inter, %{
            type: 4,
            data: %{
              content: "You don't have permission to do that",
              flags: 64
            }
          })
        end
      end

      defoverridable call: 1
    end
  end

  defp atom_perms(perm, deprecated) when perm in [:owner, :admin] do
    deprected_macro_code =
      if deprecated do
        deprecated_call()
      end

    quote do
      @behaviour Adjutant.Command.Slash
      def call(inter) do
        user_perms = Adjutant.Util.get_user_perms(inter)

        if user_perms == unquote(perm) do
          call_slash(inter)
          unquote(deprected_macro_code)
        else
          Nostrum.Api.create_interaction_response(inter, %{
            type: 4,
            data: %{
              content: "You don't have permission to do that",
              flags: 64
            }
          })
        end
      end

      defoverridable call: 1
    end
  end

  defp creation_state(creation_config) do
    quote do
      def get_creation_state do
        cmd_map = get_create_map()
        {unquote(creation_config), cmd_map}
      end
    end
  end

  defmacro __using__(opts) do
    perms_opts = Keyword.fetch!(opts, :permissions)
    deprecated = Keyword.get(opts, :deprecated, false)

    perms_ops =
      if is_list(perms_opts) do
        Enum.sort(perms_opts)
      else
        perms_opts
      end

    perms_fn =
      case perms_ops do
        :everyone ->
          everyone_perms(deprecated)

        [:admin, :owner] ->
          list_perms(deprecated)

        perms when perms in [:admin, :owner] ->
          atom_perms(perms, deprecated)

        _ ->
          raise "\":permissions\" option must be either :everyone, :admin, :owner or a list of [:admin, :owner]"
      end

    creation_fn_arg = opts[:scope] || @default_command_scope

    creation_fn = creation_state(creation_fn_arg)
    [perms_fn, creation_fn]
  end

  @typedoc """
  The name of the command
  """
  @type command_name :: String.t()

  @typedoc """
  The description of the command
  """
  @type command_desc :: String.t()

  @typedoc """
  The list of choices for a command's args, cannot be more than 25 choices per arg
  """
  @type slash_choices :: %{
          :name => String.t(),
          :value => String.t() | number()
        }

  @typedoc """
  The different kinds for a command's args
  ```
  1: SUB_COMMAND
  2: SUB_COMMAND_GROUP
  3: String,
  4: Integer,
  5: Boolean,
  6: User,
  7: Channel,
  8: Role,
  9: Mentionable,
  10: Number
  ```
  """
  @type slash_option_type :: 1..10

  @typedoc """
  What a commands options must look like,
  required choices must be before optional ones.
  Name must be between 1 and 32 characters long.
  Desc must be between 1 and 100 characters long.
  """
  @type slash_opts :: %{
          required(:type) => slash_option_type(),
          required(:name) => String.t(),
          required(:description) => String.t(),
          optional(:required) => boolean(),
          optional(:choices) => [slash_choices()],
          optional(:options) => [slash_opts()],
          optional(:autocomplete) => boolean(),
          optional(:channel_types) => [1..6]
        }

  @typedoc """
  Name must be between 1 and 32 characters long.
  Desc must be between 1 and 100 characters long.
  """
  @type slash_cmd_map :: %{
          required(:name) => String.t(),
          required(:description) => String.t(),
          optional(:type) => 1..3,
          optional(:dm_permission) => boolean(),
          optional(:default_member_permissions) => String.t(),
          optional(:options) => [slash_opts()]
        }

  @typedoc """
  A two element tuple containing the scope of the command, followed by return value of `get_create_map/0`

  The scope can be:
  `:global` - The command is created globally
  `Nostrum.Snowflake.t()` - The command is created in the guild with the given id
  `[Nostrum.Snowflake.t()]` - The command is created in the guilds with the given ids
  """
  @type creation_state ::
          {[Nostrum.Snowflake.t()] | Nostrum.Snowflake.t() | :global, slash_cmd_map()}

  @doc """
  The function that is called when the command is used
  recieves the interaction that triggered the command
  as its only argument.

  Return value is ignored.
  """
  @callback call_slash(Nostrum.Struct.Interaction.t()) :: any()

  @doc """
  The function that is called to get the map that creates the command for the module.
  See the [Discord docs][1] for more info for the expected format of the map.

  Note: This function should expect to be invoked at compile time, and as such should not
  perform any side effects.

  [1]: https://discord.com/developers/docs/interactions/application-commands
  """
  @callback get_create_map() :: slash_cmd_map()
end

defmodule Adjutant.Command.Slash.Id do
  @moduledoc """
  Defines how slash command Ids are stored and retrieved from the DB to handle
  deletion.
  """

  use Ecto.Type
  import Nostrum.Snowflake, only: [is_snowflake: 1]
  alias Nostrum.Snowflake

  @type t :: {:global, Snowflake.t()} | {:guild, [{Snowflake.t(), Snowflake.t()}]}

  def type, do: :binary

  def cast({:global, id}) when is_snowflake(id) do
    {:ok, {:global, id}}
  end

  def cast({:global, id}) when id != nil do
    case Snowflake.cast(id) do
      {:ok, id} ->
        {:ok, {:global, id}}

      :error ->
        :error
    end
  end

  def cast(id) when is_snowflake(id) do
    # assume its a global id
    IO.warn("Attempted to cast an untagged snowflake as a cmd_id, assuming it's a global id")
    {:ok, {:global, id}}
  end

  def cast({:guild, guild_id, id}) when is_snowflake(id) and is_snowflake(guild_id) do
    {:ok, {:guild, [{guild_id, id}]}}
  end

  def cast({:guild, ids}) when is_list(ids) do
    ids =
      for {guild_id, id} <- ids do
        case {Snowflake.cast(guild_id), Snowflake.cast(id)} do
          {{:ok, guild_id}, {:ok, id}} ->
            {guild_id, id}

          _ ->
            :error
        end
      end

    if Enum.any?(ids, fn id -> id == :error end) do
      :error
    else
      {:ok, {:guild, ids}}
    end
  end

  def load(id_data) when is_binary(id_data) do
    case :erlang.binary_to_term(id_data) do
      {:global, id} when is_snowflake(id) ->
        {:ok, {:global, id}}

      {:guild, ids} when is_list(ids) ->
        {:ok, {:guild, ids}}
    end
  end

  def dump({:guild, ids} = data) when is_list(ids) do
    {:ok, :erlang.term_to_binary(data)}
  end

  def dump({:global, id} = data) when is_snowflake(id) do
    {:ok, :erlang.term_to_binary(data)}
  end
end
