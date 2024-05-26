defmodule Crawldis.ExportPipeline do
  @moduledoc false
  use Broadway

  alias Broadway.Message
  alias Crawldis.ExtractedQueue
  alias Crawldis.Manager
  alias Crawldis.Config

  def start_link(crawl_job) do
    # run broadway pipeline
    init_plugins(crawl_job)

    Broadway.start_link(__MODULE__,
      name: Manager.via(__MODULE__, crawl_job.id),
      producer: [
        module: {ExtractedQueue, crawl_job},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: System.schedulers_online()]
      ],
      batchers: [
        default: [concurrency: 3, batch_size: 300, batch_timeout: 1_000]
      ],
      context: crawl_job
    )
  end

  def init_plugins(crawl_job) do
    for {plugin, opts} <- Config.get_config(:plugins, crawl_job),
        Keyword.has_key?(plugin.__info__(:functions), :init) do
      plugin.init(opts)
    end
  end

  def cleanup(crawl_job) do
    for {plugin, opts} <- Config.get_config(:plugins, crawl_job) do
      plugin.cleanup(crawl_job, opts)
    end
  end

  @impl Broadway
  def process_name({:via, module, {reg, {mod, id}}}, base_name) do
    {:via, module, {reg, {mod, id, base_name}}}
  end

  @impl Broadway
  def handle_message(_processor_name, message, crawl_job) do
    message
    |> Message.update_data(&handle_export_one(&1, crawl_job))
    |> Message.put_batcher(:default)
  end

  @impl Broadway
  def handle_batch(:default, batch, _batch_info, crawl_job) do
    batched_data = for %{data: data} <- batch, do: data
    handle_export_many(batched_data, crawl_job)

    batch
  end

  def handle_export_one(data, crawl_job) when is_map(data) do
    for {plugin, opts} <- Config.get_config(:plugins, crawl_job),
        Keyword.has_key?(plugin.__info__(:functions), :export_one),
        reduce: {:ok, data} do
      {:ok, data} -> plugin.export_one(data, crawl_job, opts)
      {:drop, _} = d -> d
    end
    |> case do
      {:ok, d} -> d
      other -> other
    end
  end

  def handle_export_many(data, crawl_job) when is_list(data) do
    for {plugin, opts} <- Config.get_config(:plugins, crawl_job),
        Keyword.has_key?(plugin.__info__(:functions), :export_many) do
      plugin.export_many(data, crawl_job, opts)
    end

    :ok
  end

  def ack(_ref, _successful, _failed) do
    :ok
  end
end
