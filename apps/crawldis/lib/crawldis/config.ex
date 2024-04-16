defmodule Crawldis.Config do
  alias Crawldis.CrawlJob
  require Logger
  @moduledoc false
  use Params.Schema, %{
    max_request_concurrency: :integer,
    max_request_rate_per_sec: :integer,
    shutdown_timeout_sec: :integer,
    plugins: [Crawldis.EctoPlugin],
    crawl_jobs: [
      %{
        name: :string,
        max_request_concurrency: :integer,
        max_request_rate_per_sec: :integer,
        start_urls: [:string],
        extract: :map,
        plugins: [Crawldis.EctoPlugin]
      }
    ]
  }

  @doc """
  Reads a config file from the provided `:config_file` location.
  """
  @spec read_config_file() :: {:ok, String.t()} | {:error, :enoent}
  def read_config_file() do
    config = Application.get_env(:crawldis, :config_file)

    if config do
      Logger.info("App configuration file found (#{config})")
    end

    File.read(config)
  end

  @doc """
  Parases a config map from a given string
  """
  @spec parse_config(String.t()) :: {:ok, %Crawldis.Config{}}
  def parse_config(str) when is_binary(str) do
    with {:ok, map} <- Jason.decode(str) do
      changeset = from(map)

      {:ok, Params.to_map(changeset)}
    end
  end

  def load_config(%__MODULE__{} = config) do
    Application.put_env(:crawldis, :init_config, config)
  end
end
