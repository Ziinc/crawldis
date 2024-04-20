defmodule Crawldis.RequestorPipeline do
  @moduledoc false
  use Broadway

  alias Broadway.Message
  alias Crawldis.Request
  alias Crawldis.RequestUrlQueue
  alias Crawldis.ExportPipeline
  alias Crawldis.Manager
  alias Crawldis.CrawlState
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

  defp do_request(%Request{} = request, crawl_job) do
    with {:ok, %Tesla.Env{status: status} = resp} when status < 400 <-
           HttpFetcher.fetch(request) do
      # Requestor.increment(resp.crawl_job_id, :scraped)
      CrawlState.touch_last_request_at(crawl_job.id)
      %{request | response: resp}
    else
      {:ok, %Tesla.Env{status: status} = resp} when status >= 400 ->
        Logger.warning("Bad request")
        %{request | response: resp}
    end
  end

  def extract_data(%Request{response: response} = request, crawl_job) do
    body = response.body

    extracted =
      for {dtype, extract_map} <- crawl_job.extract, into: %{} do
        reduced =
          for {k, v} <- extract_map, into: %{} do
            do_extraction(body, {k, v}, nil)
          end

        {dtype, reduced}
      end

    %{request | extracted_data: extracted}
  end

  defp do_extraction(doc, {key, %{} = nested}, _type) do
    {key, Enum.map(nested, fn {k, v} -> do_extraction(doc, {k, v}, nil) end)}
  end

  defp do_extraction(doc, {key, "xpath:" <> rule}, type) when is_binary(rule) do
    regex = ~r"(.+)\/\@(.+)$"
    run = Regex.run(regex, rule)

    result =
      case run do
        [_, rule_without_attr, attr] ->
          apply(Meeseeks, type || :one, [doc, xpath(rule_without_attr)])
          |> then(fn
            r when is_list(r) -> Enum.map(r, &Meeseeks.attr(&1, attr))
            r -> Meeseeks.attr(r, attr)
          end)

        _ ->
          apply(Meeseeks, type || :one, [doc, xpath(rule)])
          |> then(fn
            r when is_list(r) -> Enum.map(r, &Meeseeks.text/1)
            r -> Meeseeks.text(r)
          end)
      end

    {key, result}
  end

  defp do_extraction(doc, {key, "css:" <> rule}, type) when is_binary(rule) do
    regex = ~r"(.+)\:\:attr\([\"\'](.+)[\"\']\)$"
    run = Regex.run(regex, rule)

    result =
      case run do
        [_, rule_without_attr, attr] ->
          apply(Meeseeks, type || :one, [doc, css(rule_without_attr)])
          |> then(fn
            r when is_list(r) -> Enum.map(r, &Meeseeks.attr(&1, attr))
            r -> Meeseeks.attr(r, attr)
          end)

        _ ->
          apply(Meeseeks, type || :one, [doc, css(rule)])
          |> then(fn
            r when is_list(r) -> Enum.map(r, &Meeseeks.text/1)
            r -> Meeseeks.text(r)
          end)
      end

    {key, result}
  end

  defp do_extraction(doc, {key, rules}, _type) when is_list(rules) do
    extracted =
      Enum.flat_map(rules, fn rule ->
        {_key, results} = do_extraction(doc, {key, rule}, :all)
        results
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
