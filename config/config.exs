import Config

config :crawldis_panel, ExOauth2Provider,
  repo: CrawldisPanel.Repo,
  otp_app: :crawldis_panel,
  resource_owner: CrawldisPanel.Accounts.User,
  # default_scopes: ~w(public),
  # optional_scopes: ~w(read write),
  # revoke_refresh_token_on_use: true,
  access_token_expires_in: nil

config :crawldis_panel,
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
# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :crawly, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:crawly, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
config :logger, :console,
  format: "[$level] $message $metadata\n",
  metadata: [:data]

config :crawly,
  fetcher: {Crawly.Fetchers.HTTPoisonFetcher, []},
  retry: [
    retry_codes: [400],
    max_retries: 3,
    ignored_middlewares: [Crawly.Middlewares.UniqueRequest]
  ],

  # Stop spider after scraping certain amount of items
  closespider_itemcount: 500,
  # Stop spider if it does crawl fast enough
  closespider_timeout: 20,
  concurrent_requests_per_domain: 5,

  # TODO: this looks outdated
  follow_redirect: true,
  log_to_file: false,

  # Request middlewares
  middlewares: [
    Crawly.Middlewares.DomainFilter,
    Crawly.Middlewares.UniqueRequest,
    Crawly.Middlewares.RobotsTxt,
    {Crawly.Middlewares.UserAgent,
     user_agents: [
       "Mozilla/5.0 (Macintosh; Intel Mac OS X x.y; rv:42.0) Gecko/20100101 Firefox/42.0",
       "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36",
       "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.106 Safari/537.36 OPR/38.0.2220.41"
     ]}
  ],
  pipelines: [
    {Crawly.Pipelines.Validate, fields: [:title, :author, :time, :url]},
    {Crawly.Pipelines.DuplicatesFilter, item_id: :title},
    Crawly.Pipelines.JSONEncoder
  ]

import_config "#{Mix.env()}.exs"
import_config "local.secret.exs"
