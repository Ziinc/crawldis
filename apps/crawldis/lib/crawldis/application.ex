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
            Crawldis.Fetcher.HttpFetcher,
            {Registry, keys: :unique, name: Crawldis.CounterRegistry},
            {Registry, [name: Crawldis.ManagerRegistry, keys: :unique]}
          ] ++ common

        _ ->
          [
            Crawldis.Manager,
            Crawldis.Fetcher.HttpFetcher,
            {Registry, [name: Crawldis.ManagerRegistry, keys: :unique]},
            {Registry, keys: :unique, name: Crawldis.CounterRegistry}
          ] ++ common
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Crawldis.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
