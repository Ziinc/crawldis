defmodule Crawldis.Requestor do
  @moduledoc false
  use Supervisor

  # alias Crawldis.CrawlJob
  alias Crawldis.Manager

  def start_link(crawl_job) do
    Supervisor.start_link(__MODULE__, crawl_job,
      name: Manager.via(__MODULE__, crawl_job.id)
    )
  end

  @impl true
  def init(crawl_job) do
    # ref = :counters.new(4, [:write_concurrency])
    # {:ok, _} = Registry.register(Crawldis.CounterRegistry, crawl_job.id, ref)
    {:ok, %{job: crawl_job}}
  end

  def get_job() do
  end

  # def get_metrics(%CrawlJob{id: id}), do: get_metrics(id)
  # def get_metrics(crawl_job_id) do

  #   [{_pid, ref}] = Registry.lookup(Crawldis.CounterRegistry, crawl_job_id)
  #   metrics = (for key <- Map.keys(%CrawlJob.Metrics{}), key not in [:__struct__], into: %{} do
  #     {key, :counters.get(ref, metrics_idx(key))}
  #   end)
  #   struct(CrawlJob.Metrics, metrics)
  # end

  # def handle_call(:get_job, _caller, state) do
  #   {:state, }
  # end

  # defp metrics_idx(:seen_urls), do: 1
  # defp metrics_idx(:scraped), do: 2
  # defp metrics_idx(:extracted), do: 3
  # defp metrics_idx(:artifacts), do: 4
end
