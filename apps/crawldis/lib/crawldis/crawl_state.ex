defmodule Crawldis.CrawlState do
  use Agent

  alias Crawldis.Manager

  def start_link(crawl_job) do
    Agent.start_link(
      fn ->
        %{
          started_at: DateTime.utc_now(),
          last_request_at: nil
        }
      end,
      name: Manager.via(__MODULE__, crawl_job.id)
    )
  end

  def touch_last_request_at(id) do
    Manager.via(__MODULE__, id)
    |> Agent.cast(fn state ->
      %{state | last_request_at: DateTime.utc_now()}
    end)
  end

  def get_state(id) do
    Manager.via(__MODULE__, id)
    |> Agent.get(fn state -> state end)
  end
end
