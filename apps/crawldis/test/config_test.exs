defmodule Crawldis.ConfigTest do
  use Crawldis.CrawlCase
  alias Crawldis.Config
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
            %Config{
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

    test "load_config loads configuration to app env" do
      config = %Config{max_request_concurrency: 1234}
      assert :ok = Config.load_config(config)
      assert Application.get_env(:crawldis, :init_config) == config
    end
  end
end
