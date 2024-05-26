defmodule Crawldis.Plugins.ExportWebhook do
  @moduledoc false
  @behaviour Crawldis.Plugin
  use Params

  defparams(
    opts_params(%{
      gzip: [field: :boolean, default: true],
      url!: :string,
      max_retries: [field: :integer, default: 5],
      method!: [
        field: Ecto.Enum,
        values: [:post, :get, :delete, :put, :patch],
        default: :post
      ]
    })
  )

  @impl Crawldis.Plugin
  def export_many(data, _crawljob, opts) when is_list(data) do
    opts =
      opts
      |> Enum.into(%{})
      |> opts_params()
      |> Params.to_map()

    Tesla.client(
      [
        Tesla.Middleware.JSON,
        Tesla.Middleware.Telemetry,
        !!opts.gzip && {Tesla.Middleware.Compression, format: "gzip"},
        {Tesla.Middleware.Retry, delay: 100, max_retries: opts.max_retries}
      ]
      |> Enum.filter(& &1)
    )
    |> Tesla.request(
      url: opts.url,
      body: Jason.encode!(data),
      method: opts.method
    )

    :ok
  end
end
