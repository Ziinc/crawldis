defmodule Crawldis.Worker do
  @moduledoc false
  @doc """
  Returns the via tuple to identify the worker
  """
  @callback via(String.t()) :: tuple()

  @doc """
  Stops the worker
  """
  @callback stop(String.t()) :: :ok
end
