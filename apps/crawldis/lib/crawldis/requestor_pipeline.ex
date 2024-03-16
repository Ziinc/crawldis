defmodule Crawldis.RequestorPipeline do
  @moduledoc false
  use Broadway

  alias Broadway.Message
  alias Crawldis.RequestUrlProducer

  def start_link(crawl_job) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {RequestUrlProducer, [crawl_job]},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: System.schedulers_online()]
      ]
    )
  end

  def handle_message(_processor_name, message, _context) do
    message
    |> Message.update_data(&url_to_request/1)
    |> Message.update_data(&make_request/1)
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
end
