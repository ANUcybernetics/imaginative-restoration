import Config

config :imaginative_restoration, ImaginativeRestoration.Repo,
  database: Path.expand("../imaginative_restoration_test.db", __DIR__),
  pool_size: 5,
  # We don't run a server during test. If one is required,
  # you can enable the server option below.
  pool: Ecto.Adapters.SQL.Sandbox,
  # because some of the API tests are slow due to cold starts
  ownership_timeout: to_timeout(minute: 10)

config :imaginative_restoration, ImaginativeRestorationWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Sa/NkY7mcze1duwlfbIO6Kj9Iqx3JuJMURw1Jl5t0CCopSJwUalMbqMBNDGKvVRR",
  server: false

# Operating hours wide open during tests so AppLive/Watchdog assertions don't
# flap with wall-clock time. OperatingHours has its own tests for the real
# rules.
config :imaginative_restoration,
  operating_hours: [
    timezone: "Etc/UTC",
    start_hour: 0,
    end_hour: 24,
    weekdays: [1, 2, 3, 4, 5, 6, 7],
    blackout_ranges: []
  ]

config :imaginative_restoration, webhook_base_url: "http://localhost:4002"

# Route Replicate HTTP calls through Req.Test so tests can stub responses.
# `retry: false` keeps the default 5xx-retry from making tests slow when we
# deliberately stub an HTTP error.
config :imaginative_restoration, ImaginativeRestoration.AI.Replicate,
  plug: {Req.Test, ImaginativeRestoration.AI.Replicate},
  retry: false

# Effectively disable the sweeper's periodic timer in tests — `sweep_now/0`
# still works for explicit invocation.
config :imaginative_restoration, sweeper_interval_ms: :timer.hours(1)

# Tests drive the classifier with explicit short frame sequences; a single
# quiet tick is enough to assert the motion → rest transition.
config :imaginative_restoration, stability_window_ticks: 1

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Set up auth credentials for testing
System.put_env("AUTH_USERNAME", "test")
System.put_env("AUTH_PASSWORD", "test")
