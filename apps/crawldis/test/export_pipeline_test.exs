defmodule Crawldis.ExportPipelineTest do
  @moduledoc false
  use Crawldis.CrawlCase, async: true
  alias Crawldis.ExportPipeline
  alias Crawldis.CrawlJob
  alias Crawldis.Plugins.ExportDuplicates
  alias Crawldis.Plugins.ExportNulls
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

      assert {:ok, _} = ExportPipeline.handle_export(data, job)
      assert {:drop, :duplicate} = ExportPipeline.handle_export(data, job)
    end
  end

  describe "ExportNulls" do
    setup do
      job = %CrawlJob{id: "some-id", plugins: [{ExportNulls, []}]}
      [job: job]
    end

    test "top level", %{job: job} do
      data = %{some: nil, other: nil}
      assert {:drop, :nulls} = ExportPipeline.handle_export(data, job)
    end
    test "nested", %{job: job} do
      data = %{other: nil, some: %{other: nil}}
      assert {:drop, :nulls} = ExportPipeline.handle_export(data, job)
    end
  end
end
