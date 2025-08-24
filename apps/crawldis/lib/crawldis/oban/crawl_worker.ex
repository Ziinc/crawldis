defmodule Crawldis.Oban.CrawlWorker do
  use Oban.Worker, max_attempts: 1

  alias Crawldis.Manager
  alias Crawldis.Config
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: crawl_job}) do
    Logger.debug("#{__MODULE__} Starting crawl now : #{inspect(crawl_job)}")
    job = Config.crawl_job_params(crawl_job)
    Manager.start_job(job)
    :ok
  rescue
    exception ->
      Logger.warning(
        "Error running crawl job: #{inspect(exception)}, #{__STACKTRACE__}"
      )

      reraise exception, __STACKTRACE__
  end
end
