defmodule Crawldis.Requestor.Worker do
  use GenServer
  alias Crawldis.RequestQueue
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    send(self(), :loop)
    {:ok, %{}}
  end

  def handle_info(:loop, state) do

    case RequestQueue.pop_claimed_request() do
      {:ok, request} ->
        Logger.info("Popped claimed request for #{inspect(request.url)}")
        # do work
        Logger.debug("Starting work on request: #{request.url}")
        with {:ok, request_with_response} <- do_requesting(request),
          {:ok, %{items: items, requests: new_requests}} <- do_parsing(request_with_response) do
            # send items to processors
            Logger.debug("Sending #{length(items)} to processors")
            # send requests to request queue
            Logger.debug("Sending #{length(new_requests)} to request queue")
            for new_request <- new_requests do
              RequestQueue.add_request(new_request)
            end
        else
          {:error, _}= err->
            Logger.error("Unknown error occured while making request: #{inspect(err)}")
          {:drop, request}->
            Logger.info("Dropping request: #{request.url}")
        end
        # claim next one
        RequestQueue.claim_request()
      {:error, :no_claimed} ->
        # claim next one
      RequestQueue.claim_request()
      {:error, :queue_empty} ->
        Logger.debug("Queue empty, doing nothing")
    end

    Process.send_after(self(), :loop, 600)
    {:noreply, state}
  end

  defp do_requesting(request) do
    case Crawldis.Fetcher.HttpFetcher.fetch(request) do
      {:ok, response}->
        {:ok, Map.put(request, :response, response)}
      other -> other
    end
  end

  defp do_parsing(request_with_response) do
    case pipe(request_with_response.extractors, %Crawldis.Parsed{}, %{passthrough: false}) do
      {false, _} ->
        {:drop, request_with_response}
      {parsed, _new_state} ->
        {:ok, parsed}
    end
  end


  @spec pipe(pipelines, item, state) :: result
        when pipelines: [Crawldis.Pipeline.t()],
             item: map(),
             state: map(),
             result: {new_item | false, new_state},
             new_item: map(),
             new_state: map()
  def pipe([], item, state), do: {item, state}
  def pipe(_, false, state), do: {false, state}

  def pipe([pipeline | pipelines], item, state) do
    {module, args} =
      case pipeline do
        {module, args} ->
          {module, args}

        {module} ->
          {module, nil}

        module ->
          {module, nil}
      end

    {new_item, new_state} =
      try do
        case args do
          nil -> module.run(item, state)
          _ -> module.run(item, state, args)
        end
      catch
        error, reason ->
          call =
            case args do
              nil ->
                "#{inspect(module)}.run(#{inspect(item)}, #{inspect(state)})"

              _ ->
                "#{inspect(module)}.run(#{inspect(item)}, #{inspect(state)}, #{inspect(args)})"
            end

          Logger.error(
            "Pipeline crash by call: #{call}\n#{Exception.format(error, reason, __STACKTRACE__)}"
          )

          {item, state}
      end

    pipe(pipelines, new_item, new_state)
  end
end
