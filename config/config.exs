import Config

config :crawldis_panel, ExOauth2Provider,
  repo: CrawldisPanel.Repo,
  otp_app: :crawldis_panel,
  resource_owner: CrawldisPanel.Accounts.User,
  # default_scopes: ~w(public),
  # optional_scopes: ~w(read write),
  # revoke_refresh_token_on_use: true,
  access_token_expires_in: nil

config :crawldis_web,
  ecto_repos: [CrawldisPanel.Repo],
  generators: [context_app: false]


config :crawldis_web, :generators, context_app: :crawldis_panel

config :crawldis_web, CrawldisWeb.Endpoint,
  url: [host: "localhost", port: 4000],
  render_errors: [
    view: CrawldisWeb.ErrorView,
    accepts: ~w(html json),
    layout: false
  ],
  pubsub_server: CrawldisWeb.PubSub,
  live_view: [signing_salt: "m40y+XYz"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.29",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/crawldis_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :phoenix, :json_library, Jason

config :logger, :console,
  format: "[$level] $message $metadata\n",
  metadata: [:data, :crawl_job_id]


config :crawldis,
  ecto_repos: [Crawldis.Repo]

config :crawldis, Crawldis.Oban,
  engine: Oban.Engines.Lite,
  queues: [default: 10],
  repo: Crawldis.Repo,
  notifier: Oban.Notifiers.PG,
  peer: Oban.Peers.Global

import_config "#{Mix.env()}.exs"
# import_config "local.secret.exs"
