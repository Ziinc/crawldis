defmodule Crawldis.RequestorTest do
  @moduledoc false
  use ExUnit.Case, async: false
  alias Crawldis.Requestor
  alias Crawldis.CrawlJob
  alias Crawldis.Fetcher.HttpFetcher
  use Mimic
  setup :set_mimic_global

  describe "pipeline works" do
    test "makes a request from start urls" do
      pid = self()

      HttpFetcher
      |> expect(:fetch, fn _req ->
        send(pid, :ok)
        {:ok, %Tesla.Env{status: 200, body: "some body"}}
      end)

      job = %CrawlJob{id: UUID.uuid4(), start_urls: ["http://localhost:123"]}
      start_supervised!({Requestor, job})

      :timer.sleep(2000)
      assert_receive :ok
    end
  end
end
