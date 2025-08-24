defmodule Crawldis.JobSup do
  @moduledoc false
  alias Crawldis.Manager
  alias Crawldis.RequestorPipeline
  alias Crawldis.ExportPipeline
  alias Crawldis.Config
  alias Crawldis.CrawlState
  use GenServer, restart: :transient, shutdown: 5_000
  require Logger

  def start_link(crawl_job) do
    GenServer.start_link(__MODULE__, crawl_job,
      name: Manager.via(__MODULE__, crawl_job.id)
    )
  end

  @impl true
  def init(crawl_job) do
    plugins = Config.get_config(:plugins, crawl_job)

    Logger.debug(
      "Initializing #{Enum.count(plugins)} plugins for job #{crawl_job.id}"
    )

    for {plugin, opts} <- plugins do
      plugin.init(opts)
    end

    children = [
      {CrawlState, crawl_job},
      {ExportPipeline, crawl_job},
      {RequestorPipeline, crawl_job}
    ]

    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
    {:ok, crawl_job}
  end
end
