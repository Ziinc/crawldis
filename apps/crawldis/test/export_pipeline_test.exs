defmodule Crawldis.ExportPipelineTest do
  @moduledoc false
  use Crawldis.CrawlCase, async: false
  alias Crawldis.ExportPipeline
  alias Crawldis.CrawlJob
  alias Crawldis.Plugins.ExportDuplicates
  alias Crawldis.Plugins.ExportNulls
  alias Crawldis.Plugins.ExportWebhook
  import ExportNulls, only: [all_nulls?: 1]
  doctest ExportNulls

  describe "ExportDuplicates" do
    setup do
      job = %CrawlJob{id: "some-id", plugins: [{ExportDuplicates, []}]}
      ExportPipeline.init_plugins(job)

      on_exit(fn ->
        ExportPipeline.cleanup(job)
      end)

      [job: job]
    end

    test "drop strategy", %{job: job} do
      data = %{some: "data", other: "value"}

      assert %{} = ExportPipeline.handle_export_one(data, job)
      assert {:drop, :duplicate} = ExportPipeline.handle_export_one(data, job)
    end
  end

  describe "ExportNulls" do
    setup do
      job = %CrawlJob{id: "some-id", plugins: [{ExportNulls, []}]}
      [job: job]
    end

    test "top level", %{job: job} do
      data = %{some: nil, other: nil}
      assert {:drop, :nulls} = ExportPipeline.handle_export_one(data, job)
    end

    test "nested", %{job: job} do
      data = %{other: nil, some: %{other: nil}}
      assert {:drop, :nulls} = ExportPipeline.handle_export_one(data, job)
    end
  end

  describe "ExportWebhook" do
    test "sends request based on options" do
      pid = self()
      ref = make_ref()

      Tesla
      |> expect(:request, fn _client, req ->
        send(pid, {ref, Jason.decode!(req[:body])})
        %Tesla.Env{}
      end)

      job = %CrawlJob{
        id: "some-id",
        plugins: [{ExportWebhook, [url: "http://localhost:4321"]}]
      }

      data = %{"some" => nil, "other" => nil}
      assert :ok = ExportPipeline.handle_export_many([data], job)
      arr = [data]
      assert_receive {^ref, ^arr}, 1_500
    end
  end
end
