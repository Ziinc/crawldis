defmodule Crawldis.Manager do
  @moduledoc """
  Crawl job node-level manager for a cluster. Syncs state across nodes.any()

  The sole purpose of the Manager is to cache job information and metadata, as well as to connect to the control plane.
  """
  alias Crawldis.JobDynSup
  alias Crawldis.Manager
  alias Crawldis.JobSup
  alias Crawldis.CrawlJob
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # add in request queue
      # Manager.Worker,
      # {Syncer, [name: __MODULE__.Syncer, get_pid: get_pid]}
      # {Agent, name}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # API

  def via(id) do
    {:via, Registry, {Crawldis.ManagerRegistry, id}}
  end

  def via(mod, id) do
    {:via, Registry, {Crawldis.ManagerRegistry, {mod, id}}}
  end

  @spec start_job(map() | keyword()) :: {:ok, Manager.CrawlJob.t()}
  def start_job(job) do
    job =
      Enum.into(job, %{id: UUID.uuid4()})
      |> then(&struct(CrawlJob, &1))

    case DynamicSupervisor.start_child(JobDynSup, {JobSup, job}) do
      {:ok, _pid} -> {:ok, job}
    end
  end

  @spec list_jobs :: [Manager.CrawlJob.t()]
  def list_jobs do
    for {_id, child, _type, _mod} <- DynamicSupervisor.which_children(JobDynSup) do
      JobSup.get_job(child)
    end
  end

  @spec get_job(binary()) :: Manager.CrawlJob.t()
  def get_job(id) when is_binary(id),
    do: GenServer.call(Manager.Worker, {:get_job, id})

  # @spec get_metrics(binary()) :: Manager.CrawlJob.Metrics.t()
  # def get_metrics(id) when is_binary(id),
  #     do: GenServer.call(__MODULE__, {:get_metrics, id})

  @spec stop_job(binary() | :all) :: :ok
  def stop_job(id_or_type),
    do: GenServer.cast(Manager.Worker, {:stop_job, id_or_type})

  # # callbacks
  # def handle_call({:get_metrics, id}, _caller, state) do
  #   id
  #   |> Requestor.via()
  #   |> Requestor.get_metrics()
  # end
end
