defmodule Crawldis.Manager do
  @moduledoc """
  Crawl job node-level manager for a cluster. Syncs state across nodes.any()

  The sole purpose of the Manager is to cache job information and metadata, as well as to connect to the control plane.
  """
  alias Crawldis.JobDynSup
  alias Crawldis.Manager
  alias Crawldis.JobFlame
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
      case job do
        %CrawlJob{} ->
          %{job | id: UUID.uuid4()}

        _ ->
          Enum.into(job, %{id: UUID.uuid4()})
          |> then(&struct(CrawlJob, &1))
      end

    case DynamicSupervisor.start_child(JobDynSup, %{
           id: job.id,
           start: {JobFlame, :start_link, [job]}
         }) do
      {:ok, _pid} -> {:ok, job}
    end
  end

  @spec list_jobs :: [Manager.CrawlJob.t()]
  def list_jobs do
    for {_key, _pid, value} <-
          Registry.select(Crawldis.JobRegistry, [
            {{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
          ]) do
      value
    end
  end

  @spec get_job(String.t()) :: CrawlJob.t() | nil
  def get_job(id) do
    case Registry.lookup(Crawldis.JobRegistry, id) do
      [{_pid, job}] -> job
      _ -> nil
    end
  end

  # @spec get_metrics(binary()) :: Manager.CrawlJob.Metrics.t()
  # def get_metrics(id) when is_binary(id),
  #     do: GenServer.call(__MODULE__, {:get_metrics, id})

  @spec stop_job(binary() | :all) :: :ok
  def stop_job(id) do
    case Registry.lookup(Crawldis.JobRegistry, id) do
      [{pid, _job}] ->
        DynamicSupervisor.terminate_child(JobDynSup, pid)

      _ ->
        :ok
    end

    :ok
  end

  # # callbacks
  # def handle_call({:get_metrics, id}, _caller, state) do
  #   id
  #   |> Requestor.via()
  #   |> Requestor.get_metrics()
  # end
end
