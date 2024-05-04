defmodule Crawldis.AutoShutdownMonitor do
  @moduledoc false
  alias Crawldis.Manager
  alias Crawldis.RequestorPipeline
  alias Crawldis.ExportPipeline
  alias Crawldis.Config
  alias Crawldis.CrawlState
  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    loop(3_000)
    {:ok, %{last_idle: nil}}
  end

  @impl true
  def handle_info(:maybe_shutdown, %{last_idle: nil} = state) do
    jobs = Manager.list_jobs()
    count = Enum.count(jobs)

    Logger.debug("checking if idle")

    if count > 0 do
      loop(3000)
      {:noreply, state}
    else
      loop(1000)
      {:noreply, %{last_idle: DateTime.utc_now()}}
    end
  end

  def handle_info(:maybe_shutdown, %{last_idle: last_idle} = state) do
    jobs = Manager.list_jobs()
    count = Enum.count(jobs)

    cond do
      count > 0 ->
        loop(3000)
        {:noreply, %{last_idle: nil}}

      DateTime.diff(DateTime.utc_now(), last_idle) <= shutdown_timeout() ->
        Logger.debug("System idle timeout reached, shutting down crawldis")
        {:stop, :normal, state}

      true ->
        loop(1_000)
        {:noreply, state}
    end
  end

  def terminate(reason, state) do
    if reason == :normal do
      Logger.info("Shutting down crawldis")
      System.stop()
    end
  end

  defp loop(ms) do
    Process.send_after(self(), :maybe_shutdown, ms)
  end

  defp shutdown_timeout() do
    Config.get_config(:system_shutdown_timeout_sec)
  end
end
