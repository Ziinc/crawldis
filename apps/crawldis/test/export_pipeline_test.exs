defmodule Crawldis.ExportPipelineTest do
  @moduledoc false
  use Crawldis.CrawlCase, async: true
  alias Crawldis.ExportPipeline
  alias Crawldis.CrawlJob
  alias Crawldis.Plugins.ExportDuplicates

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
end
