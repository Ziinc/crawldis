defmodule Crawldis.Plugins.ExportJsonl do
  @moduledoc false
  @behaviour Crawldis.Plugin

  @impl Crawldis.Plugin
  def init(opts) do
    path = Path.expand(opts[:dir])
    File.mkdir_p!(path)

    %{
      dir_path: path
    }
  end

  @impl Crawldis.Plugin
  def export_many(data, _crawljob, opts) do
    dir = Path.expand(opts[:dir])

    # convert
    grouped =
      for datum <- data, {file, value} <- datum, reduce: %{} do
        acc when is_map_key(acc, file) -> Map.update!(acc, file, &[value | &1])
        acc -> Map.put(acc, file, [value])
      end

    for {file, value} <- grouped do
      path = Path.join(dir, file <> ".jsonl")
      File.write(path, Jason.encode!(value) <> "\n", [:append])
    end
  end
end
