import Config
# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.

config :logger, :console,
  level: :error

config :crawldis_panel, CrawldisPanel.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "crawldis_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :crawldis_web, CrawldisWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base:
    "xLXG96aORZPhYVkjM5+t9L3ztjZJx5FnqKxXhfYNp8r7JTPImwUw7DBOqsTV7W+B",
  server: true

config :crawldis, Crawldis.Oban, testing: :inline

config :crawldis, Crawldis.Repo,
  database: ":memory:",
  pool_size: 1
