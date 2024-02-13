defmodule Crawldis.Fetcher do
  @moduledoc """
  A behavior module for defining Fetchers

  A fetcher is expected to implement a fetch callback which should take
  Crawldis.Request, HTTP client options and return Crawldis.Response.
  """

  @type t :: {module(), list()}

  @callback fetch(request, options) :: {:ok, response} | {:error, reason}
            when request: Crawldis.Request.t(),
                 response: Crawldis.Response.t(),
                 options: keyword(),
                 reason: term()
end
