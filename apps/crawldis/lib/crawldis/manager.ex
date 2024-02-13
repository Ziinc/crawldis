defmodule Crawldis.Manager do
  @moduledoc """
  Crawl job node-level manager for a cluster. Syncs state across nodes.any()

  The sole purpose of the Manager is to cache job information and metadata, as well as to connect to the control plane.
  """
  alias Crawldis.Syncer
  alias Crawldis.Manager
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    get_pid = fn ->
      Manager.Worker.get_state()
      |> Map.get(:crdt_pid)
    end

    children = [
      # add in request queue
      Manager.Worker,
      {Syncer, [name: __MODULE__.Syncer, get_pid: get_pid]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # API

  @spec start_job(map()) :: {:ok, Manager.CrawlJob.t()}
  def start_job(job), do: GenServer.call(Manager.Worker, {:start_job, job})

  @spec list_jobs :: [Manager.CrawlJob.t()]
  def list_jobs, do: GenServer.call(Manager.Worker, :list_jobs)

  @spec get_job(binary()) :: Manager.CrawlJob.t()
  def get_job(id) when is_binary(id),
    do: GenServer.call(Manager.Worker, {:get_job, id})

  @spec stop_job(binary() | :all) :: :ok
  def stop_job(id_or_type),
    do: GenServer.cast(Manager.Worker, {:stop_job, id_or_type})
end
