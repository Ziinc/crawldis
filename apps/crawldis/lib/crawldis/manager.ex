defmodule Crawldis.Manager do
  @moduledoc """
  Crawl job node-level manager for a cluster. Syncs state across nodes.any()

  The sole purpose of the Manager is to cache job information and metadata, as well as to connect to the control plane.
  """
  alias Crawldis.JobDynSup
  alias Crawldis.Manager
  alias Crawldis.JobFlame
  alias Crawldis.CrawlJob
  alias Crawldis.Scheduler
  alias Crawldis.Oban.CrawlWorker
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
  def start_job(params) do
    job = params_to_job(params)

    case DynamicSupervisor.start_child(JobDynSup, %{
           id: job.id,
           start: {JobFlame, :start_link, [job]},
           restart: :transient
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

  @doc """
  Queues a crawl job using Oban to be started immediately.
  """
  @spec queue_job(CrawlJob.t() | map() | keyword()) :: :ok
  def queue_job(params), do: queue_jobs([params])

  def queue_jobs(list_of_params) when is_list(list_of_params) do
    changesets =
      for params <- list_of_params do
        job = params_to_job(params)
        CrawlWorker.new(job)
      end

    Crawldis.Oban
    |> Oban.insert_all(changesets)

    :ok
  end

  @doc """
  Schedule's a cron job on citrine.
  """
  @spec schedule_job(CrawlJob.t() | map() | keyword()) ::
          :ok | {:error, :no_cron}
  def schedule_job(params) do
    job = params_to_job(params)

    if job.cron do
      Scheduler.put_job(%Citrine.Job{
        id: job.id,
        # Run every second
        schedule: job.cron,
        task: {__MODULE__, :queue_job, [job]},
        # Use extended cron syntax
        extended_syntax: true
      })

      :ok
    else
      {:error, :no_cron}
    end
  end

  @doc """
  List jobs that are scheduled on Citrine.
  """
  @spec list_scheduled_jobs() :: [CrawlJob.t()]
  def list_scheduled_jobs() do
    for {_pid, %_{task: {_, :queue_job, [job]}}} <-
          Scheduler.list_jobs() do
      job
    end
  end

  @doc """
  Deletes all scheduled jobs on Citrine
  """
  @spec delete_scheduled_jobs() :: :ok
  def delete_scheduled_jobs do
    for {_pid, %_{id: job_id}} <- Scheduler.list_jobs() do
      Scheduler.delete_job(job_id)
    end

    :ok
  end

  defp params_to_job(params) do
    case params do
      %CrawlJob{} ->
        %{params | id: UUID.uuid4()}

      _ ->
        Enum.into(params, %{id: UUID.uuid4()})
        |> then(&struct(CrawlJob, &1))
    end
  end
end
