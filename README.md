Just another rewrite of Adjutant to learn Elixir

Has some interop with https://github.com/Th3-M4jor/BnBBackend-EX and private github webook for auto-redeployment of two frontend-projects.

# Project setup guide
After cloning the repo, the following steps are required to compile:
- create a file named `COOKIE` in the root directory of the repo with a random string as the contents
- run `mix deps.get` to install all dependencies
- in the `config` directory create a file named `dev.exs` then copy into it `example_config.exs`


# Running the bot
To run the bot the following extra things will be needed:
- A connection to a postgres database with the following tables:
    - `"Virus"`
    - `"NaviCust"`
    - `"Battlechip"`
    - An `Oban` migration for the respective version of the library
- A development sqlite DB for logging and storing state about slash commands
  - This can be created by running `mix ecto.create -r Adjutant.Repo.SQLite`
  - Said DB must then be migrated `mix ecto.migrate -r Adjutant.Repo.SQLite`
- In `config/dev.exs` the `token:` config will need an actual bot token

The bot should then be able to be successfully started by running:
`iex -S mix`

# Production use
The same above steps for development will need to be run, except with the following changes:
- `config/dev.exs` will need to be replaced with `config/prod.exs`
- SQLite DB creation and migration will need to be done with the env var `MIX_ENV` set to `"prod"`

The bot can then be run with `MIX_ENV` set to prod, however it is recommended to instead use a `mix release` for production use.


# Adding a command
To add a new command to the bot, the following steps are required:
- Create a new module for the command in the `lib/commands` directory
  - it is recommended to namespace the command's module name with `Adjutant.Commands`
- This new module should `use` the `Adjutant.Command.Slash` module
  - See the documentation for the `Adjutant.Command.Slash` module for more information
  - Also, see [`Adjutant.Command.Slash.BNB.PHB`](lib/command/slash/bnb/phb.ex) for a simple example
- Add this new module to the `@commands` list in the [`Adjutant.Command`](lib/command.ex) module
- The bot will take care of creating the command if it doesn't exist at startup

# Deleting a command
To delete a command, the following steps are required:
- Remove the module from the `@commands` list in the [`Adjutant.Command`](lib/command.ex) module
- Add the module to the `@deleted_commands` list in the [`Adjutant.Command`](lib/command.ex) module
- The bot will take care of deleting the command if its recorded as existing at startup
- Then on future rollouts you can delete the module

# Renaming a command
To rename a command, you must first delete the command and then add it again with the new name.
An alternative option may be considered in the future if this happens often enough.
