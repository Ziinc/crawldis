defmodule Crawldis.Response do
  @moduledoc false

  defstruct body: nil,
            headers: [],
            request: nil,
            request_url: nil,
            status_code: nil

  @type t :: %__MODULE__{
          body: term(),
          headers: list(),
          request: Crawldis.Request.t(),
          request_url: Crawldis.Request.url(),
          status_code: integer()
        }
end
