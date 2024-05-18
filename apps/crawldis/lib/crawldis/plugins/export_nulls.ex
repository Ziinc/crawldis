defmodule Crawldis.Plugins.ExportNulls do
  @moduledoc false
  @behaviour Crawldis.Plugin

  @impl Crawldis.Plugin
  def export(data, _job, opts) do
    opts = Enum.into(opts, %{strategy: "drop"})

    if opts.strategy == "drop" and all_nulls?(data) do
      {:drop, :nulls}
    else
      {:ok, data}
    end
  end

  @doc """
  Recursively checks if all keys are nils
    iex> all_nulls?(%{some: nil})
    true
    iex> all_nulls?(%{some: "value"})
    false
    iex> all_nulls?(%{other: %{some: nil}})
    true
  """
  def all_nulls?(data) do
    Enum.all?(data, fn
      {_k, nil} -> true
      {_k, v} when is_list(v) or is_map(v) -> all_nulls?(v)
      _ -> false
    end)
  end
end
