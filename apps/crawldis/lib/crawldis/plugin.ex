defmodule Crawldis.Plugin do
  @moduledoc false

  @callback init(keyword()) :: map()
  @callback export(map(), keyword()) :: term() | :ok
end
