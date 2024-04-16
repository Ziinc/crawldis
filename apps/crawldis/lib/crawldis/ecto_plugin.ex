defmodule Crawldis.EctoPlugin do
  use Ecto.Type
  def type, do: :plugin

  def cast([mod, %{} = map_opts]) when is_binary(mod) do
    opts = convert_to_klist(map_opts)
    cast({mod, opts})
  end

  def cast({mod, opts}) when is_binary(mod) and is_list(opts) do
    module = Module.concat([Crawldis.Plugins, mod])
    {:ok, {module, opts}}
  end

  def cast({mod, opts}) when is_atom(mod) and is_list(opts) do
    {:ok, {mod, opts}}
  end

  def cast(_), do: :error

  def load(_data), do: :error
  def dump(_), do: :error

  def convert_to_klist(map) do
    Enum.map(map, fn {key, value} -> {String.to_existing_atom(key), value} end)
  end
end
