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

  pipeline :mcp do
    plug :accepts, ["json"]
  end

  # MCP (Model Context Protocol) servers - must come before catch-all routes
  scope "/tidewave/mcp" do
    pipe_through :mcp
    forward "/", Tidewave.Router
  end

  scope "/ash_ai/mcp" do
    pipe_through :mcp

    forward "/", AshAi.Mcp.Router,
      tools: [
        :read_sketches,
        :create_sketch,
        :crop_and_label_sketch,
        :process_sketch,
        :read_prompts,
        :get_latest_prompt
      ],
      protocol_version_statement: "2024-11-05",
      otp_app: :imaginative_restoration
  end

  scope "/", ImaginativeRestorationWeb do
    pipe_through :browser

    live "/", AppLive

    live "/config", ConfigLive

    live "/prompts", PromptLive

    # catch-all route for the error handler
    live "/*path", ErrorLive, :index, as: :error
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
