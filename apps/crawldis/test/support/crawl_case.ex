defmodule Crawldis.CrawlCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      use Mimic
      setup :set_mimic_global
      setup :verify_on_exit!
    end
  end

  setup tags do
    Crawldis.CrawlCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid =
      Ecto.Adapters.SQL.Sandbox.start_owner!(CrawldisPanel.Repo,
        shared: not tags[:async]
      )

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
