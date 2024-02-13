defmodule CrawldisWeb.Presence do
  @moduledoc false
  use Phoenix.Presence,
    otp_app: :crawldis_web,
    pubsub_server: CrawldisWeb.PubSub
end
