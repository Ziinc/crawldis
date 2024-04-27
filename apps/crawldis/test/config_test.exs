defmodule Crawldis.ConfigTest do
  use Crawldis.CrawlCase
  alias Crawldis.Config
  alias Crawldis.CrawlJob
  alias Crawldis.Plugins.ExportJsonl

  test "parse_config/1 from string" do
    input = ~S"""
    {
      "max_request_concurrency": 123,
      "plugins": [
        ["ExportJsonl", {"dir": "tmp"}]
      ]
    }
    """

    assert {:ok,
            %{
              max_request_concurrency: 123,
              plugins: [
                {ExportJsonl, dir: "tmp"}
              ]
            }} = Config.parse_config(input)
  end

  describe "app env" do
    setup do
      initial = Application.get_env(:crawldis, :init_config)

      on_exit(fn ->
        Application.put_env(:crawldis, :init_config, initial)
      end)
    end

    test "loads global configuration to app env" do
      config = %Config{max_request_concurrency: 1234}
      assert :ok = Config.load_config(config)
      assert Application.get_env(:crawldis, :init_config) == config
    end

    test "get_config resolves correct level of config" do
      assert Config.get_config(:max_request_concurrency) == 5

      assert :ok = Config.load_config(%Config{max_request_concurrency: 1234})
      assert Config.get_config(:max_request_concurrency) == 1234

      job = %CrawlJob{max_request_concurrency: 55}
      assert Config.get_config(:max_request_concurrency, job) == 55
    end
  end
end
