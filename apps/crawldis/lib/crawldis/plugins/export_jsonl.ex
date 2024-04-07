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
  def export(data, opts) do
    dir = Path.expand(opts[:dir])

    for {file, value} <- data do
      path = Path.join(dir, file <> ".jsonl")
      File.write(path, Jason.encode!(value), [:append])
    end
  end
end
