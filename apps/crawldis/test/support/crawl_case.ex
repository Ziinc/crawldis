defmodule Crawldis.CrawlCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Mimic
      setup :set_mimic_global
      setup :verify_on_exit!
    end
  end
end
