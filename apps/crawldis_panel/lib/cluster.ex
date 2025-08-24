defmodule CrawldisPanel.Cluster do
  @moduledoc false
  alias CrawldisPanel.Accounts.User

  def get_access_token(%User{} = user) do
    oauth_config = get_config()

    ExOauth2Provider.AccessTokens.get_authorized_tokens_for(user, oauth_config)
    |> List.first()
  end

  def create_access_token(%User{} = user) do
    oauth_config = get_config()
    ExOauth2Provider.AccessTokens.create_token(user, %{}, oauth_config)
  end

  def verify_token(token) when is_binary(token) do
    oauth_config = get_config()
    ExOauth2Provider.authenticate_token(token, oauth_config)
  end

  defp get_config do
    Application.get_env(:crawldis_panel, ExOauth2Provider)
  end
end
