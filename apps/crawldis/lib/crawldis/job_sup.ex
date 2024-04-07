defmodule Crawldis.JobSup do
  @moduledoc false
  alias Crawldis.Manager
  alias Crawldis.RequestorPipeline
  alias Crawldis.ExportPipeline
  alias Crawldis.CrawlState
  use GenServer

  def start_link(crawl_job) do
    GenServer.start_link(__MODULE__, crawl_job,
      name: Manager.via(__MODULE__, crawl_job.id)
    )
  end

  @impl true
  def init(crawl_job) do
    for {plugin, opts} <- crawl_job.plugins do
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
            job.shutdown_timeout_sec ->
        {:stop, :normal, job}

      crawl_state.last_request_at != nil and
          DateTime.diff(DateTime.utc_now(), crawl_state.last_request_at) >=
            job.shutdown_timeout_sec ->
        {:stop, :normal, job}

      true ->
        loop(job)
        {:noreply, job}
    end
  end

  defp loop(crawl_job) do
    factor = if(crawl_job.shutdown_timeout_sec > 0, do: 400, else: 200)

    Process.send_after(
      self(),
      :maybe_shutdown,
      round(factor * crawl_job.shutdown_timeout_sec)
    )
  end
end
