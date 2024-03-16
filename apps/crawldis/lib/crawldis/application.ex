defmodule Crawldis.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

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
            {Registry, keys: :unique, name: Crawldis.CounterRegistry},
            {Registry,
             [name: Crawldis.ManagerRegistry, keys: :unique, members: :auto]}
          ] ++ common

        _ ->
          [
            Crawldis.Cluster,
            Crawldis.RequestQueue,
            Crawldis.Manager,
            Crawldis.Connector,
            Crawldis.Fetcher.HttpFetcher,
            Crawldis.RequestPipeline,
            {Registry, keys: :unique, name: Crawldis.CounterRegistry}
          ] ++ common
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Crawldis.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
