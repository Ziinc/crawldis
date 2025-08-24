defmodule Crawldis.Plugin do
  @moduledoc false

  alias Crawldis.CrawlJob

  @callback init(keyword()) :: map()
  @callback cleanup(CrawlJob.t()) :: map()
  @callback export_one(map(), CrawlJob.t(), keyword()) :: term() | :ok
  @callback export_many([map()], CrawlJob.t(), keyword()) :: term() | :ok
  @optional_callbacks init: 1, cleanup: 1, export_one: 3, export_many: 3
end
