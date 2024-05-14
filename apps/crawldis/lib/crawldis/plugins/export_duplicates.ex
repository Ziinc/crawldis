defmodule Crawldis.Plugins.ExportDuplicates do
  @moduledoc false
  alias Crawldis.CrawlJob
  import Ex2ms
  @behaviour Crawldis.Plugin

  @impl Crawldis.Plugin

  @table_name :export_hashtable

  def init(_opts) do
    if :ets.whereis(@table_name) == :undefined do
      :ets.new(@table_name, [:set, :public, :named_table])
    end

    %{}
  end

  def cleanup(%CrawlJob{id: id}, _opts \\ []) do
    if :ets.whereis(@table_name) != :undefined do
      ms =
        fun do
          {x, _y} = z when x == ^id -> z
        end

      :ets.match_delete(@table_name, ms)
    end
  end

  @impl Crawldis.Plugin
  def export(data, %CrawlJob{} = job, opts) do
    opts = Enum.into(opts, %{strategy: "drop"})
    hash = do_hash(data)
    duplicate? = :ets.member(@table_name, {job.id, hash})

    if opts.strategy == "drop" and duplicate? do
      {:drop, :duplicate}
    else
      :ets.insert(@table_name, {{job.id, hash}, data})
      {:ok, data}
    end
  end

  defp do_hash(term), do: :erlang.phash2(term, trunc(:math.pow(2, 32)))
end
