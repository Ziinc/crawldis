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
    loop(crawl_job)
    {:ok, crawl_job}
  end

  def get_job(pid) do
    GenServer.call(pid, :get_job)
  end

  @impl true
  def handle_call(:get_job, _caller, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:maybe_shutdown, job) do
    crawl_state = CrawlState.get_state(job.id)

    cond do
      crawl_state.last_request_at == nil and
          DateTime.diff(DateTime.utc_now(), crawl_state.started_at) >=
            shutdown_timeout(job) ->
        Logger.debug(
          "Stopping job #{job.id}, no requests made and timeout reached"
        )

        {:stop, :normal, job}

      crawl_state.last_request_at != nil and
          DateTime.diff(DateTime.utc_now(), crawl_state.last_request_at) >=
            shutdown_timeout(job) ->
        Logger.debug("Stopping job #{job.id}, timeout reached")
        {:stop, :normal, job}

      true ->
        loop(job)
        {:noreply, job}
    end
  end

  defp loop(job) do
    factor = if(shutdown_timeout(job) > 0, do: 400, else: 200)

    Process.send_after(
      self(),
      :maybe_shutdown,
      round(factor * shutdown_timeout(job))
    )
  end

  defp shutdown_timeout(job) do
    Config.get_config(:shutdown_timeout_sec, job)
  end
end
