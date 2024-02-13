defmodule Crawldis.RequestorPipeline do
  @moduledoc false
  use Broadway

  alias Broadway.Message

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {Crawldis.RequestProducer, []}
      ],
      processors: [
        default: [concurrency: System.schedulers_online() * 2]
      ]
    )
  end

  def handle_message(_processor_name, message, _context) do
    message
    |> Message.update_data(&process_data/1)
  end

  defp process_data(_data) do
    # Do some calculations, generate a JSON representation, process images.
  end
end
