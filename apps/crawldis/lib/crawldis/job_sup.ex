defmodule Crawldis.JobSup do
  @moduledoc false
  alias Crawldis.Manager

  use GenServer

  def start_link(crawl_job) do
    GenServer.start_link(__MODULE__, crawl_job,
      name: Manager.via(__MODULE__, crawl_job.id)
    )
  end

  @impl true
  def init(crawl_job) do
    children = [
      # {Crawldis.RequestorPipeline, crawl_job}
      # {Agent, fn -> %{crawl_job: crawl_job} end}
    ]

    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
    {:ok, crawl_job}
  end

  def get_job(pid) do
    GenServer.call(pid, :get_job)
  end

  @impl true
  def handle_call(:get_job, _caller, state) do
    {:reply, state, state}
  end
end
