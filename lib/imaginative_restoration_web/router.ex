defmodule ImaginativeRestorationWeb.Router do
  use ImaginativeRestorationWeb, :router

  pipeline :browser do
    plug :auth
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ImaginativeRestorationWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ImaginativeRestorationWeb do
    pipe_through :browser

    live "/", AppLive

    live "/config", ConfigLive

    live "/prompts", PromptLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", ImaginativeRestorationWeb do
  #   pipe_through :api
  # end

  defp auth(conn, _opts) do
    username = System.fetch_env!("AUTH_USERNAME")
    password = System.fetch_env!("AUTH_PASSWORD")
    Plug.BasicAuth.basic_auth(conn, username: username, password: password)
  end
end
