defmodule Crawldis.Plugin do
  @moduledoc false

  alias Crawldis.CrawlJob

  @callback init(keyword()) :: map()
  @callback cleanup(CrawlJob.t()) :: map()
  @callback export(map(), CrawlJob.t(), keyword()) :: term() | :ok
  @optional_callbacks init: 1, cleanup: 1, export: 3
end
