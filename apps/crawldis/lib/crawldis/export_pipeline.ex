defmodule Crawldis.ExportPipeline do
  @moduledoc false
  use Broadway

  alias Broadway.Message
  alias Crawldis.ExtractedQueue
  alias Crawldis.Manager

  def start_link(crawl_job) do
    # run broadway pipeline
    Broadway.start_link(__MODULE__,
      name: Manager.via(__MODULE__, crawl_job.id),
      producer: [
        module: {ExtractedQueue, crawl_job},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: System.schedulers_online()]
      ],
      context: crawl_job
    )
  end

  @impl Broadway
  def process_name({:via, module, {reg, {mod, id}}}, base_name) do
    {:via, module, {reg, {mod, id, base_name}}}
  end

  def handle_message(_processor_name, message, crawl_job) do
    message
    |> Message.update_data(&do_export(&1, crawl_job))
  end

  defp do_export(data, crawl_job) do
    for {plugin, opts} <- crawl_job.plugins,
        Keyword.has_key?(plugin.__info__(:functions), :export) do
      plugin.export(data, opts)
    end

    data
  end

  defp url_to_request(url) do
    %Crawldis.Request{url: url}
  end

  defp make_request(%Crawldis.Request{} = request) do
    with {:ok, %Tesla.Env{status: status} = resp} when status < 400 <-
           Crawldis.Fetcher.HttpFetcher.fetch(request) do
      # Requestor.increment(resp.crawl_job_id, :scraped)
      %{request | response: resp}
    end
  end

  def ack(_ref, successful, failed) do
    :ok
  end
end
