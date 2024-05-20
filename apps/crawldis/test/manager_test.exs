defmodule Crawldis.ManagerTest do
  use Crawldis.CrawlCase, async: false
  alias Crawldis.Manager
  alias Crawldis.CrawlJob
  alias Crawldis.Fetcher.HttpFetcher
  alias Crawldis.JobDynSup
  alias Crawldis.Plugins.ExportJsonl
  alias Crawldis.Config
  alias Crawldis.Manager

  setup do
    start_supervised!(Crawldis.Manager)

    on_exit(fn ->
      for {_id, child, _type, _mod} <-
            DynamicSupervisor.which_children(JobDynSup) do
        DynamicSupervisor.terminate_child(JobDynSup, child)
      end

      :timer.sleep(500)
    end)

    :ok
  end

  defp stub_fetcher(_ctx) do
    HttpFetcher
    |> stub(:fetch, fn _req ->
      {:ok, %Tesla.Env{status: 200, body: "some body"}}
    end)

    :ok
  end

  describe "management" do
    setup [:stub_fetcher]

    test "start/stop a job" do
      assert {:ok, %CrawlJob{id: id, start_urls: [_]}} =
               Manager.start_job(start_urls: ["http://localhost:4321"])

      :timer.sleep(500)

      assert [%CrawlJob{}] = Manager.list_jobs()
      assert :ok = Manager.stop_job(id)
      :timer.sleep(500)
      assert [] == Manager.list_jobs()
    end

    test "shutdown_timeout_sec" do
      assert {:ok, _} =
               Manager.start_job(
                 start_urls: [
                   "http://localhost:4321"
                 ],
                 shutdown_timeout_sec: 0.2
               )

      :timer.sleep(1_500)
      assert [] == Manager.list_jobs()
    end

    test "shutdown_timeout_sec with no requests" do
      assert {:ok, _} =
               Manager.start_job(
                 start_urls: [],
                 shutdown_timeout_sec: 0.1
               )

      :timer.sleep(1_500)
      assert [] == Manager.list_jobs()
    end
  end

  test "rate_limiting" do
    HttpFetcher
    |> expect(:fetch, 1, fn _req ->
      {:ok, %Tesla.Env{status: 200, body: "some body"}}
    end)

    assert {:ok, _} =
             Manager.start_job(
               start_urls: [
                 "http://www.localhost:4555",
                 "http://www.localhost:4556",
                 "http://www.localhost:4557",
                 "http://www.localhost:4558"
               ],
               max_request_rate_per_sec: 1
             )

    :timer.sleep(1_000)
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
    setup [:stub_fetcher]

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
      pid = self()
      ref1 = make_ref()
      ref2 = make_ref()

      HttpFetcher
      |> expect(:fetch, 1, fn _req ->
        send(pid, ref1)
        {:ok, %Tesla.Env{status: 200, body: "some body"}}
      end)

      ExportJsonl
      |> expect(:export, 1, fn _req, _job, _ ->
        send(pid, ref2)
        :ok
      end)

      assert {:ok, _} =
               Manager.start_job(
                 start_urls: [
                   "http://localhost:4022",
                   "http://localhost:4023",
                   "http://localhost:4024",
                   "http://localhost:4025",
                   "http://localhost:4026"
                 ]
               )

      :timer.sleep(500)
      assert_received ^ref1
      assert_received ^ref2
    end
  end

  describe "request pipeline" do
    setup [:stub_fetcher]

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

    test "follow links" do
      pid = self()
      ref1 = make_ref()
      ref2 = make_ref()

      HttpFetcher
      |> expect(:fetch, 2, fn req ->
        if req.url =~ "some-other-path" do
          send(pid, ref2)
        else
          send(pid, ref1)
        end

        {:ok,
         %Tesla.Env{
           status: 200,
           body: """
           <div>
             <a href="http://localhost:4444/some-other-path">testing</a>
           </div>
           """
         }}
      end)

      assert {:ok, %CrawlJob{}} =
               Manager.start_job(%CrawlJob{
                 start_urls: ["http://localhost:4444"],
                 follow_rules: ["css:div a::attr('href')"],
                 extract: %{},
                 plugins: []
               })

      assert_receive ^ref1, 1000
      assert_receive ^ref2, 1500
    end

    test "follow links drop duplicates" do
      pid = self()

      HttpFetcher
      |> expect(:fetch, 3, fn req ->
        send(pid, req.url)

        {:ok,
         %Tesla.Env{
           status: 200,
           body: """
           <div>
             <a href="http://localhost:4444/some-other-path">testing</a>
             <a href="http://localhost:4444/some-other-path">testing</a>
             <a href="http://localhost:4444/some-other-path">testing</a>
             <a href="http://localhost:4444/some-other-path">testing</a>
             <a href="http://localhost:4444/some-other-path">testing</a>
             <a href="http://localhost:4444/some-path">testing</a>
           </div>
           """
         }}
      end)

      assert {:ok, %CrawlJob{}} =
               Manager.start_job(%CrawlJob{
                 start_urls: ["http://localhost:4444"],
                 follow_rules: ["css:div a::attr('href')"],
                 extract: %{},
                 plugins: []
               })

      assert_receive "http://localhost:4444", 1_000
      assert_receive "http://localhost:4444/some-path", 1_000
      assert_receive "http://localhost:4444/some-other-path", 1_000
    end

    test "exported" do
      HttpFetcher
      |> expect(:fetch, fn _req ->
        {:ok,
         %Tesla.Env{status: 200, body: "<div id=\"item\">test_value</div>"}}
      end)

      # start job
      assert {:ok, %CrawlJob{}} =
               Manager.start_job(
                 start_urls: ["http://localhost:4022"],
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

  describe "citrine" do
    setup do
      start_link_supervised!(Crawldis.Oban)
      start_link_supervised!(Crawldis.Scheduler)

      :ok
    end

    test "queue_job/1 enqueues an oban job" do
      HttpFetcher
      |> expect(:fetch, 1, fn _req ->
        {:ok, %Tesla.Env{status: 200, body: "some body"}}
      end)

      assert :ok =
               Manager.queue_job(
                 start_urls: [
                   "http://www.localhost:4555"
                 ]
               )

      :timer.sleep(1_000)
    end

    test "schedule_job/1 schedules a job on citrine" do
      HttpFetcher
      |> expect(:fetch, 1, fn _req ->
        {:ok, %Tesla.Env{status: 200, body: "some body"}}
      end)

      assert :ok =
               Manager.schedule_job(
                 start_urls: [
                   "http://www.localhost:4555"
                 ],
                 cron: "* * * * * *"
               )

      :timer.sleep(1_500)
      assert [%CrawlJob{cron: "* * * * * *"}] = Manager.list_scheduled_jobs()
    end
  end
end
