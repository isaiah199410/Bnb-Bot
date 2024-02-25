# rename this file to "config.exs", replace the token and it'll run
# however it's recommended to have a "dev.exs" and a "prod.exs"
# where the "config.exs" only does `import_config "#{config_env()}.exs"`
import Config

config :nostrum,
  # The token of your bot as a string
  token: "token_here",
  # The number of shards you want to run your bot under, or :auto.
  num_shards: :auto,
  gateway_intents: [
    :direct_messages,
    :guild_bans,
    :guild_members,
    :guild_message_reactions,
    :guild_messages,
    :guild_presences,
    :guilds
  ]

config :logger,
  level: :info,
  backends: [
    :console,
    {Adjutant.LogBackend, :log_backend}
  ],
  compile_time_purge_matching: [
    [module: Nostrum, level_lower_than: :warn],
    [module: Nostrum.Api, level_lower_than: :warn],
    [module: Nostrum.Application, level_lower_than: :warn],
    [module: Nostrum.Shard.Dispatch, level_lower_than: :warn],
    [module: Nostrum.Shard.Event, level_lower_than: :warn]
  ]

config :adjutant, Oban,
  repo: Adjutant.Repo.SQLite,
  engine: Oban.Engines.Lite,
  queues: [
    remind_me: [limit: 2, paused: true],
    edit_message: [limit: 2, paused: true],
    log_cleaner: [limit: 1, paused: false]
  ],
  plugins: [
    {Oban.Plugins.Reindexer, schedule: "@weekly"},
    {Oban.Plugins.Pruner, max_age: 50 * 60, interval: :timer.minutes(500)},
    {Oban.Plugins.Lifeline, interval: :timer.minutes(60)},
    {Oban.Plugins.Cron,
     crontab: [
       {"@weekly", Adjutant.Workers.LogCleaner}
     ]}
  ]

# uses sqlite for logging
config :adjutant, Adjutant.Repo.SQLite,
  database: "./db/dev_db.db",
  priv: "priv/sqlite"

# uses postgres for storing BnB data, and for Oban
config :adjutant, Adjutant.Repo.Postgres,
  username: "postgres",
  password: "postgres",
  database: "default",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  priv: "priv/postgres"

config :adjutant,
  ecto_repos: [Adjutant.Repo.SQLite, Adjutant.Repo.Postgres],
  ecto_shard_count: 1,
  remind_me_queue: :dev_remind_me,
  edit_message_queue: :dev_edit_message,
  log_cleaner_queue: :dev_log_cleaner,
  prefix: "!",
  owner_id: 666,
  admins: [667, 668],
  dm_log_id: 999,
  primary_guild_id: 555,
  primary_guild_channel_id: 12_354_456_457_567,
  primary_guild_role_channel_id: 669,
  default_command_scope: 555,
  hidden_command_scope: 555,
  owner_command_scope: 666,
  backend_node_name: :foo@bar,
  webhook_node_name: :baz@bar,
  ncp_url: "https://bnb.api/jin-tengai.dev/fetch/ncps",
  chip_url: "https://bnb.api/jin-tengai.dev/fetch/chips",
  virus_url: "https://bnb.api/jin-tengai.dev/fetch/viruses",
  phb_links: [
    %{
      type: 2,
      style: 5,
      label: "B&B PHB",
      url: "https://phb.jin-tengai.dev/#!/home"
    },
    %{
      type: 2,
      style: 5,
      label: "Manager",
      url: "https://manager.jin-tengai.dev/"
    }
  ],
  ncp_emoji: %{
    white: %{
      id: nil,
      name: "\u{2B1C}"
    },
    pink: %{
      id: "912046716767830036",
      name: "pink_square"
    },
    yellow: %{
      id: nil,
      name: "\u{1F7E8}"
    },
    green: %{
      id: nil,
      name: "\u{1F7E9}"
    },
    blue: %{
      id: nil,
      name: "\u{1F7E6}"
    },
    red: %{
      id: nil,
      name: "\u{1F7E5}"
    },
    gray: %{
      id: "912054778421448705",
      name: "gray_square"
    }
    # id: nil,

    # jigsaw emoji
    # name: "\u{1F9E9}"
  },
  virus_emoji: %{
    id: nil,

    # space invader emoji
    name: "\u{1F47E}"
  },
  chip_emoji: %{
    id: "695852335943122974",
    name: "SynchroChip"
  },
  roles: [
    %{
      id: "579769580441042945",
      name: "Role Name",
      emoji: %{
        id: "695852335943122974",
        name: "SynchroChip"
      },
      style: 1
    }
  ],
  # these can be strings for unicode emojis, or tupules with {name, id} or {name, id, animated}
  # where name is the name of the emoji, id is the id of the emoji, and animated is a boolean
  # for using custom emojis
  troll_emojis: [
    "👿",
    "🍆",
    "🤡",
    "🔥",
    "💀",
    "🇹🇩",
    "🗿"
  ]
