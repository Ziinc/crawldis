defmodule Crawldis.ManagerTest do
  use ExUnit.Case
  alias Crawldis.{Manager, RequestQueue}
  alias Crawldis.Manager.CrawlJob

  @job %{start_urls: ["http://www.some url.com"]}
  setup do
    start_supervised!(Crawldis.RequestQueue)
    start_supervised!(Crawldis.Manager)
    :ok
  end

  test "start a job" do
    assert {:ok, %CrawlJob{id: id, start_urls: [_]}} = Manager.start_job(@job)
    assert [_] = Manager.list_jobs()
    assert @job = Manager.get_job(id)
    assert is_binary(id)
    assert RequestQueue.count_requests() > 0
  end

  describe "update" do
    setup [:start_job]

    test "stops a job", %{job: job} do
      # start another job, so should have 1 request in queue after
      start_job([])
      assert RequestQueue.count_requests() == 2
      assert :ok = Manager.stop_job(job.id)
      :timer.sleep(300)
      assert Manager.list_jobs() |> length() == 1
      # clears request queue
      assert RequestQueue.count_requests() == 1
    end
  end

  defp start_job(_) do
    {:ok, job} = Manager.start_job(@job)
    {:ok, job: job}
  end
end
