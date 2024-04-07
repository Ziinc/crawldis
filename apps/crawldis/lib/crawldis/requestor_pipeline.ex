defmodule Crawldis.RequestorPipeline do
  @moduledoc false
  use Broadway

  alias Broadway.Message
  alias Crawldis.Request
  alias Crawldis.RequestUrlQueue
  alias Crawldis.ExportPipeline
  alias Crawldis.Manager
  alias Crawldis.Fetcher.HttpFetcher
  import Meeseeks.CSS
  import Meeseeks.XPath

  require Logger

  def start_link(crawl_job) do
    Broadway.start_link(__MODULE__,
      name: Manager.via(__MODULE__, crawl_job.id),
      producer: [
        module: {RequestUrlQueue, crawl_job},
        concurrency: 1,
        rate_limiting: [
          allowed_messages: crawl_job.max_request_rate_per_sec,
          interval: 1_000
        ]
      ],
      processors: [
        default: [concurrency: crawl_job.max_request_concurrency, max_demand: 1]
      ],
      context: crawl_job
    )
  end

  @impl Broadway
  def process_name({:via, module, {reg, {mod, id}}}, base_name) do
    {:via, module, {reg, {mod, id, base_name}}}
  end

  @impl Broadway
  def handle_message(_processor_name, message, context) do
    message
    |> Message.update_data(&url_to_request/1)
    |> Message.update_data(&do_request(&1, context))
    # |> Message.update_data(&extract_artifacts/1)
    # |> Message.update_data(&extract_links/1)
    |> Message.update_data(&extract_data(&1, context))
  end

  defp url_to_request(url) do
    %Request{url: url}
  end

  defp do_request(%Request{} = request, _crawl_job) do
    with {:ok, %Tesla.Env{status: status} = resp} when status < 400 <-
           HttpFetcher.fetch(request) do
      # Requestor.increment(resp.crawl_job_id, :scraped)
      %{request | response: resp}
    end
  end

  defp extract_data(%Request{response: response} = request, crawl_job) do
    body = response.body

    extracted =
      for {dtype, extract_map} <- crawl_job.extract, into: %{} do
        reduced =
          for {k, v} <- extract_map, into: %{} do
            do_extraction(body, {k, v})
          end

        {dtype, reduced}
      end

    %{request | extracted_data: extracted}
  end

  defp do_extraction(doc, {key, %{} = nested}) do
    {key, Enum.map(nested, fn {k, v} -> do_extraction(doc, {k, v}) end)}
  end

  defp do_extraction(doc, {key, "xpath:" <> rule}) when is_binary(rule) do
    {key, Meeseeks.one(doc, xpath(rule)) |> Meeseeks.text()}
  end

  defp do_extraction(doc, {key, "css:" <> rule}) when is_binary(rule) do
    {key, Meeseeks.one(doc, css(rule)) |> Meeseeks.text()}
  end

  defp do_extraction(doc, {key, rules}) when is_list(rules) do
    extracted =
      Enum.flat_map(rules, fn
        "css:" <> rule ->
          Meeseeks.all(doc, css(rule)) |> Enum.map(&Meeseeks.text/2)

        "xpath:" <> rule ->
          Meeseeks.all(doc, xpath(rule)) |> Enum.map(&Meeseeks.text/2)
      end)

    {key, extracted}
  end

  # defp extract_artifacts(%Request{artifact_extractor: nil} = request) do
  #   %{request | artifacts: [request.body]}
  # end

  # defp extract_links(%Request{follow_link_extractors: nil} = request) do
  #   %{request | follow_links: []}
  # end
  # defp extract_links(%Request{artifacts: artifacts, follow_link_extractors: extractors} = request) do
  # for rule <- extractors, artifact <- artifacts do
  #   case rule do
  #     {:xpath, rule} -> Meeseeks.all(document, xpath("//*[@id='main']//p")
  #   end

  #   result = Meeseeks.one(document, xpath("//*[@id='main']//p"))

  #   {:ok, doc} = Floki.parse_document(html)
  #   doc
  #   |> Floki.find(rule)
  #   |> Floki.text()
  # end
  #   %{request | follow_links: []}
  # end

  def ack(ref, successful, _failed) do
    to_push =
      for msg <- successful,
          msg.data.extracted_data,
          do: %Broadway.Message{
            data: msg.data.extracted_data,
            acknowledger: {ExportPipeline, ref, nil}
          }

    via = Manager.via(ExportPipeline, ref)

    case GenServer.whereis(via) do
      nil ->
        Logger.warning(
          "Unable to push artifacts to ExportPipeline as process is not alive. crawl_job_id: #{ref}",
          crawl_job_id: ref
        )

      _pid ->
        Broadway.push_messages(via, to_push)
    end

    :ok
  end
end
