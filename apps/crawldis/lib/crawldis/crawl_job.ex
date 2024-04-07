defmodule Crawldis.CrawlJob do
  @moduledoc """
  A crawl job, with all configuration required for requestors/processors.
  """
  @derive Jason.Encoder
  use TypedStruct

  typedstruct do
    field(:id, String.t())
    field(:max_request_concurrency, non_neg_integer(), default: 5)
    field(:max_request_rate_per_sec, non_neg_integer(), default: 10)
    field(:shutdown_timeout_sec, non_neg_integer(), default: 5)
    field(:start_urls, [String.t()])
    field(:metrics, __MODULE__.Metrics.t())
    field(:extract, %{String.t() => map()}, default: %{})
    field(:plugins, [{module(), keyword()}], default: [])
  end

  defmodule Metrics do
    @moduledoc false
    use TypedStruct

    typedstruct do
      field(:scraped, non_neg_integer(), default: 0)
      field(:seen_urls, non_neg_integer(), default: 0)
      field(:artifacts, non_neg_integer(), default: 0)
      field(:extracted, non_neg_integer(), default: 0)
    end
  end
end
