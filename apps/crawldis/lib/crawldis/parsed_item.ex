defmodule Crawldis.Parsed do
  @moduledoc false

  defstruct items: [], requests: []

  @type item() :: map()
  @type t :: %__MODULE__{
          items: [item()],
          requests: [Crawldis.Request.t()]
        }
end
