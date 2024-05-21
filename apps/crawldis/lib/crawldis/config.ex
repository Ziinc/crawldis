defmodule Crawldis.Config do
  @moduledoc false
  alias Crawldis.CrawlJob
  require Logger

  use Params.Schema, %{
    max_request_concurrency: [field: :integer, default: 5],
    max_request_rate_per_sec: [field: :integer, default: 10],
    system_shutdown_timeout_sec: [field: :integer],
    shutdown_timeout_sec: [field: :integer, default: 5],
    extract: [field: :map, default: Macro.escape(%{})],
    plugins: [Crawldis.EctoPlugin],
    crawl_jobs: [
      %{
        name: :string,
        cron: [field: :string, default: nil],
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

      config =
        Params.to_map(changeset)
        |> Enum.into(%{
          plugins: []
        })

      {:ok, struct(__MODULE__, config)}
    end
  end

  def crawl_job_params(params) do
    from(%{"crawl_jobs" => [params]})
    |> Params.to_map()
    |> Map.get(:crawl_jobs)
    |> hd()
  end

  @doc "Sets config to the :init_config env"
  @spec load_config(%__MODULE__{}) :: :ok
  def load_config(%__MODULE__{} = config) do
    Application.put_env(:crawldis, :init_config, config)
  end

  @doc "Resolves configuration values at either global or job level"
  @spec get_config(atom()) :: term() | nil
  @spec get_config(atom(), CrawlJob.t()) :: term() | nil
  def get_config(key) do
    env =
      Application.get_env(:crawldis, :init_config) ||
        %__MODULE__{plugins: [], extract: %{}}

    Map.get(env, key)
  end

  def get_config(key, %CrawlJob{} = job) do
    Map.get(job, key) || get_config(key)
  end
end
