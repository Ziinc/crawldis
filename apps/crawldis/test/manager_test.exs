defmodule Crawldis.ManagerTest do
  use Crawldis.CrawlCase, async: false
  alias Crawldis.Manager
  alias Crawldis.CrawlJob
  alias Crawldis.Fetcher.HttpFetcher
  alias Crawldis.JobDynSup
  alias Crawldis.Plugins.ExportJsonl
  alias Crawldis.Config

  setup do
    start_supervised!(Crawldis.Manager)

    HttpFetcher
    |> stub(:fetch, fn _req ->
      {:ok, %Tesla.Env{status: 200, body: "some body"}}
    end)

    on_exit(fn ->
      for {_id, child, _type, _mod} <-
            DynamicSupervisor.which_children(JobDynSup) do
        DynamicSupervisor.terminate_child(JobDynSup, child)
      end
    end)

    :ok
  end

  test "start/stop a job" do
    assert {:ok, %CrawlJob{id: id, start_urls: [_]}} =
             Manager.start_job(start_urls: ["http://www.some url.com"])

    :timer.sleep(500)

    assert [%CrawlJob{}] = Manager.list_jobs()
    assert :ok = Manager.stop_job(id)
    assert [] == Manager.list_jobs()
  end

  test "rate_limiting" do
    HttpFetcher
    |> expect(:fetch, 1, fn _req ->
      {:ok, %Tesla.Env{status: 200, body: "some body"}}
    end)

    assert {:ok, _} =
             Manager.start_job(
               start_urls: [
                 "http://www.some url.com",
                 "http://www.some url2.com",
                 "http://www.some url3.com",
                 "http://www.some url4.com"
               ],
               max_request_rate_per_sec: 1
             )

    :timer.sleep(500)
  end

  test "shutdown_timeout_sec" do
    assert {:ok, _} =
             Manager.start_job(
               start_urls: [
                 "http://www.some url.com"
               ],
               shutdown_timeout_sec: 0.1
             )

    :timer.sleep(1000)
    assert [] == Manager.list_jobs()
  end

  test "shutdown_timeout_sec with no requests" do
    assert {:ok, _} =
             Manager.start_job(
               start_urls: [],
               shutdown_timeout_sec: 0.1
             )

    :timer.sleep(1000)
    assert [] == Manager.list_jobs()
  end

  test "max_request_concurrency" do
    HttpFetcher
    |> expect(:fetch, 2, fn _req ->
      :timer.sleep(1000)
      {:ok, %Tesla.Env{status: 200, body: "some body"}}
    end)

    assert {:ok, _} =
             Manager.start_job(
               start_urls: [
                 "http://www.some url.com",
                 "http://www.some url2.com"
               ],
               max_request_concurrency: 2
             )

    :timer.sleep(200)
  end

  describe "global configs" do
    setup do
      initial = Application.get_env(:crawldis, :init_config)

      on_exit(fn ->
        Application.put_env(:crawldis, :init_config, initial)
      end)
    end

    test "acts as fallback values - max_request_concurrency" do
      config = %Config{
        max_request_concurrency: 1,
        plugins: [{ExportJsonl, dir: "tmp/data"}]
      }

      assert :ok = Config.load_config(config)

      HttpFetcher
      |> expect(:fetch, 1, fn req ->
        dbg(req)
        {:ok, %Tesla.Env{status: 200, body: "some body"}}
      end)

      ExportJsonl
      |> expect(:export, 1, fn _req, _ ->
        :ok
      end)

      assert {:ok, _} =
               Manager.start_job(
                 start_urls: [
                   "http://www.some url.com",
                   "http://www.some url2.com",
                   "http://www.some url3.com",
                   "http://www.some url4.com",
                   "http://www.some url5.com"
                 ]
               )

      :timer.sleep(500)
      verify!()
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
                 extract: %{"my_data" => %{"my_value" => "css:#item"}},
                 plugins: [{ExportJsonl, dir: "tmp/data"}]
               )

      :timer.sleep(500)

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
end
