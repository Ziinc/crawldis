defmodule Crawldis.ManagerTest do
  use ExUnit.Case
  alias Crawldis.Manager
  alias Crawldis.CrawlJob
  alias Crawldis.Fetcher.HttpFetcher
  use Mimic

  @job %{
    start_urls: ["http://www.some url.com"],
    plugins: [],
    extract: %{}
  }
  setup do
    start_supervised!(Crawldis.Manager)

    HttpFetcher
    |> stub(:fetch, fn _req ->
      {:ok, %Tesla.Env{status: 200, body: "some body"}}
    end)

    :ok
  end

  test "start a job" do
    assert {:ok, %CrawlJob{id: _id, start_urls: [_]}} =
             Manager.start_job(start_urls: ["http://www.some url.com"])

    assert [_] = Manager.list_jobs()
  end

  describe "update" do
    setup [:start_job]

    test "stops a job", %{job: job} do
      assert :ok = Manager.stop_job(job.id)
      :timer.sleep(300)
      assert Manager.list_jobs() |> length() == 0
    end
  end

  describe "request pipeline" do
    setup do
      on_exit(fn ->
        File.rm_rf!("tmp")
      end)

      :ok
    end

    # test "one job pipeline started per job" do
    #   HttpFetcher
    #   |> expect(:fetch, fn req -> {:ok, %Tesla.Env{status: 200, body: "some body"}} end)

    #   # start job
    #   assert {:ok, %CrawlJob{} = job} = Manager.start_job(@job)

    #   :timer.sleep(1000)
    #   # check metrics, scraped count, seen count, artifacts count
    #   # assert %CrawlJob.Metrics{
    #   #   scraped: 1,
    #   #   seen_urls: 1,
    #   #   artifacts: 1,
    #   #   extracted: 0
    #   # } = Requestor.get_metrics(job.id)

    # end

    # test "artifacts" do

    #   HttpFetcher
    #   |> expect(:fetch, fn req -> {:ok, %Tesla.Env{status: 200, body: "some body"}} end)

    #   assert {:ok, %CrawlJob{}} = Manager.start_job(%CrawlJob{
    #     start_urls: ["http://www.some url.com"],
    #     plugins: [],
    #     extract: %{}
    #   })
    #   :timer.sleep(1000)

    #   assert [file ] = File.ls!("tmp/artifacts")
    #   assert File.read!(file) =~ "some body"
    #   # assert %CrawlJob.Metrics{
    #   #   extracted: 0,
    #   #   artifacts: 1,
    #   # } = Manager.get_metrics(job.id)

    # end

    test "exported" do
      HttpFetcher
      |> expect(:fetch, fn _req ->
        {:ok,
         %Tesla.Env{status: 200, body: "<div id=\"item\">test_value</div>"}}
      end)

      # start job
      assert {:ok, %CrawlJob{}} =
               Manager.start_job(
                 start_urls: ["http://www.some url.com"],
                 exract: %{"my_data" => %{"my_value" => "#item"}},
                 plugins: [{ExportJsonl, dir: "tmp/data"}]
               )

      # assert %CrawlJob.Metrics{
      #   extracted: 1,
      # } = Manager.get_metrics(job.id)

      # check exported data
      jsonl = File.read!("tmp/data/my_data.jsonl")
      assert jsonl =~ "test_value"
      assert jsonl =~ "my_value"
      refute jsonl =~ "div"
    end
  end

  defp start_job(_) do
    {:ok, job} = Manager.start_job(@job)
    {:ok, job: job}
  end
end
