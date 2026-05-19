# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ash, :default_belongs_to_type, :integer

# Use tzdata so OperatingHours can resolve "Australia/Sydney" across DST.
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

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
  # Capture gate. All three values are on RMSE * 100 (0-100 scale) except the
  # last, which is a tick count.
  #
  # The classifier is a small motion → rest → compare state machine. A trigger
  # requires (a) motion to have been observed since the last capture, (b) the
  # scene to have been quiet for `stability_window_ticks` consecutive frames,
  # and (c) the current frame to differ from the last-captured baseline by
  # more than `image_difference_threshold`. The motion-precondition prevents
  # slow camera AGC/lighting drift from ever triggering on its own.
  #
  #   * `image_difference_threshold` — change vs baseline to bother triggering.
  #
  #   * `frame_settle_threshold` — per-tick frame-to-frame diff above which we
  #     treat the scene as in motion. Sits just above the static-scene noise
  #     floor (measured ~1.65 in prod).
  #
  #   * `stability_window_ticks` — consecutive frames that must be at or below
  #     `frame_settle_threshold` before we'll consider the scene at rest.
  image_difference_threshold: 2.5,
  frame_settle_threshold: 2.0,
  stability_window_ticks: 3,
  webcam_capture_interval: 1_000,
  # Safety net: LiveView clears its in-flight submission lock if a sketch
  # broadcast never arrives. Sweeper handles the DB side after 5 min; this
  # is the matching LV-side timeout.
  lock_timeout_ms: to_timeout(second: 420),
  # Operating hours for the installation. The server drops frames received
  # outside these hours, and the watchdog uses the same gate to decide
  # whether silence is unexpected. See ImaginativeRestoration.OperatingHours.
  operating_hours: [
    timezone: "Australia/Sydney",
    start_hour: 9,
    end_hour: 22,
    weekdays: [1, 2, 3, 4, 5],
    blackout_ranges: [
      # MM-DD pairs; if start > end, the range wraps the year boundary.
      {{12, 21}, {1, 6}}
    ]
  ]

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
