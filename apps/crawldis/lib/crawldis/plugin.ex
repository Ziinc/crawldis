defmodule Crawldis.Plugin do
  @moduledoc false

  alias Crawldis.CrawlJob

  @callback init(keyword()) :: map()
  @callback export(map(), CrawlJob.t(), keyword()) :: term() | :ok
end
