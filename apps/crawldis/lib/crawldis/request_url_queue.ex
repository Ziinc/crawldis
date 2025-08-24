defmodule Crawldis.RequestUrlQueue do
  @moduledoc false
  use GenStage
  alias Crawldis.RequestorPipeline

  @impl true
  def init(job) do
    {:producer,
     %{
       demand: 0,
       queue: :queue.from_list(job.start_urls),
       crawl_job_id: job.id
     }}
  end

  @impl true
  def handle_demand(incoming_demand, state) do
    len = :queue.len(state.queue)
    new_demand = incoming_demand + state.demand

    {rem, demanded, queue} =
      if len < new_demand do
        {new_demand - len, :queue.to_list(state.queue), :queue.new()}
      else
        {demanded_queue, queue} = :queue.split(new_demand, state.queue)
        {0, :queue.to_list(demanded_queue), queue}
      end

    {:noreply, to_message(demanded, state.crawl_job_id),
     %{state | queue: queue, demand: rem}}
  end

  # Called to insert urls into the queue.
  @impl true
  def handle_info({:queue, urls}, state) do
    queue = :queue.join(state.queue, :queue.from_list(urls))

    # maybe emit based on demand demand
    {demanded, queue} =
      if state.demand > 0 do
        {demanded_queue, queue} = :queue.split(state.demand, queue)
        {:queue.to_list(demanded_queue), queue}
      else
        {[], queue}
      end

    {:noreply, to_message(demanded, state.crawl_job_id),
     %{state | queue: queue}}
  end

  defp to_message(urls, crawl_job_id) do
    for url <- urls do
      %Broadway.Message{
        data: url,
        acknowledger: {RequestorPipeline, crawl_job_id, nil}
      }
    end
  end
end
