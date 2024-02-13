defmodule Crawldis.Pipeline do
  @moduledoc false
  @callback run(item :: map, state :: map()) ::
              {new_item :: map, new_state :: map}
              | {false, new_state :: map}

  @callback run(item :: map, state :: map(), args :: list(any())) ::
              {new_item :: map, new_state :: map}
              | {false, new_state :: map}
  @optional_callbacks run: 3
end
