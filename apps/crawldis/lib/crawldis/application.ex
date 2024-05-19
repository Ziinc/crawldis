defmodule Crawldis.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger
  alias Crawldis.Config
  alias Crawldis.Manager

  @impl true
  def start(_type, _args) do
    env = Application.get_env(:crawldis, :env)

    flame_parent = FLAME.Parent.get()

    common =
      [
        !flame_parent && Crawldis.Repo,
        !flame_parent && Crawldis.Oban,
        !flame_parent && Crawldis.Scheduler,
        {DynamicSupervisor, strategy: :one_for_one, name: Crawldis.JobDynSup},
        {Registry, keys: :unique, name: Crawldis.JobRegistry},
        {FLAME.Pool,
         name: Crawldis.JobRunnerPool,
         min: 0,
         max: 10,
         max_concurrency: 100,
         idle_shutdown_after: 30_000}
      ]
      |> Enum.filter(& &1)

    children =
      case env do
        :test ->
          [
            Crawldis.Fetcher.HttpFetcher,
            {Registry, keys: :unique, name: Crawldis.CounterRegistry},
            {Registry,
             keys: :unique,
             name: Crawldis.UrlRegistry,
             partitions: System.schedulers_online()},
            {Registry, [name: Crawldis.ManagerRegistry, keys: :unique]}
          ] ++ common

        _ ->
          [
            Crawldis.Manager,
            Crawldis.AutoShutdownMonitor,
            Crawldis.Fetcher.HttpFetcher,
            {Registry, [name: Crawldis.ManagerRegistry, keys: :unique]},
            {Registry,
             keys: :unique,
             name: Crawldis.UrlRegistry,
             partitions: System.schedulers_online()},
            {Registry, keys: :unique, name: Crawldis.CounterRegistry}
          ] ++
            common ++
            [
              {Task, &startup_tasks/0}
            ]
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Crawldis.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def startup_tasks do
    # start jobs
    with {:ok, str} <- Config.read_config_file(),
         {:ok, config} <- Config.parse_config(str) do
      Logger.info("Found #{Enum.count(config.crawl_jobs)} crawl job(s)")
      Config.load_config(config)

      for job <- config.crawl_jobs do
        if job.cron do
          Manager.schedule_job(job)
        else
          Manager.queue_job(job)
        end
      end
    else
      {:error, :enoent} ->
        Logger.warning("No config file found")
    end
  end
end
