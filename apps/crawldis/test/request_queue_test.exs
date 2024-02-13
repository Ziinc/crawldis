defmodule Crawldis.RequestQueueTest do
  use ExUnit.Case, async: false
  alias Crawldis.RequestQueue
  doctest RequestQueue

  @request %Crawldis.Request{
    crawl_job_id: "123",
    url: "http://www.some url.com"
  }
  setup do
    start_supervised!(Crawldis.RequestQueue)
    :ok
  end

  test "add a request to a queue" do
    assert :ok = RequestQueue.add_request(@request)
    assert RequestQueue.count_requests() == 1
    assert RequestQueue.list_requests() |> length == 1
  end

  describe "update" do
    setup [:add_request]

    test "claim a request from the queue" do
      assert :ok = RequestQueue.claim_request()
      assert RequestQueue.count_requests(:claimed) == 1
      assert RequestQueue.list_requests(:unclaimed) |> length == 0
    end

    test "pop a claimed request from queue" do
      assert :ok = RequestQueue.claim_request()
      :timer.sleep(1000)

      assert {:ok, %Crawldis.Request{} = req} =
               RequestQueue.pop_claimed_request()

      assert req == @request
      assert RequestQueue.count_requests() == 0
      assert RequestQueue.list_requests() |> length == 0
    end

    test "clear queue" do
      assert :ok = RequestQueue.clear_requests()
      assert RequestQueue.count_requests() == 0
      assert RequestQueue.list_requests() |> length == 0
    end

    test "clear request by crawl id" do
      assert :ok =
               RequestQueue.clear_requests_by_crawl_job_id(
                 @request.crawl_job_id
               )

      assert RequestQueue.count_requests() == 0
    end
  end

  defp add_request(_) do
    RequestQueue.add_request(@request)
  end
end
