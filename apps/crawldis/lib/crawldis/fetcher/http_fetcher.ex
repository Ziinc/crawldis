defmodule Crawldis.Fetcher.HttpFetcher do
  @moduledoc false
  use Hardhat
  plug(Tesla.Middleware.FollowRedirects)
  alias Crawldis.Request
  alias Crawldis.Fetcher
  @behaviour Fetcher

  @impl Fetcher
  def fetch(%Request{url: url}, _opts \\ []) do
    get(url)
  end
end
