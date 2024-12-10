# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ash, :default_belongs_to_type, :integer

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  imaginative_restoration: [
    args: ~w(js/app.js --bundle --target=es2020 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures the endpoint
config :imaginative_restoration, ImaginativeRestorationWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ImaginativeRestorationWeb.ErrorLive],
    layout: false
  ],
  pubsub_server: ImaginativeRestoration.PubSub,
  live_view: [signing_salt: "NTxy6HlN"]

config :imaginative_restoration,
  ecto_repos: [ImaginativeRestoration.Repo],
  ash_domains: [ImaginativeRestoration.Sketches],
  generators: [timestamp_type: :utc_datetime]

config :imaginative_restoration,
  image_difference_threshold: 3,
  webcam_capture_interval: 60_000

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  imaginative_restoration: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
