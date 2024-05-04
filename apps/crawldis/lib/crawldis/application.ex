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

    common = [
      {DynamicSupervisor, strategy: :one_for_one, name: Crawldis.JobDynSup}
    ]

    children =
      case env do
        :test ->
          [
            Crawldis.Fetcher.HttpFetcher,
            {Registry, keys: :unique, name: Crawldis.CounterRegistry},
            {Registry, [name: Crawldis.ManagerRegistry, keys: :unique]}
          ] ++ common

        _ ->
          [
            Crawldis.Manager,
            Crawldis.AutoShutdownMonitor,
            Crawldis.Fetcher.HttpFetcher,
            {Registry, [name: Crawldis.ManagerRegistry, keys: :unique]},
            {Registry, keys: :unique, name: Crawldis.CounterRegistry}
          ] ++
            common ++
            [
              {Task, &startup_task/0}
            ]
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Crawldis.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp startup_task do
    # start jobs
    with {:ok, str} <- Config.read_config_file(),
         {:ok, config} <- Config.parse_config(str) do
      Logger.info("Found #{Enum.count(config.crawl_jobs)} crawl job(s)")

      for job <- config.crawl_jobs do
        Manager.start_job(job)
      end
    else
      {:error, :enoent} ->
        Logger.warning("No config file found")
    end
  end
end
