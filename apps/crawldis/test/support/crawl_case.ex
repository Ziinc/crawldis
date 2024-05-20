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
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Crawldis.Repo)
    # Setting the shared mode must be done only after checkout
    Ecto.Adapters.SQL.Sandbox.mode(Crawldis.Repo, {:shared, self()})
  end
end
