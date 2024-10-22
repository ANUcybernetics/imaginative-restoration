import Config

config :imaginative_restoration, ImaginativeRestoration.Repo,
  database: Path.expand("../imaginative_restoration_test.db", __DIR__),
  pool_size: 5,
  # We don't run a server during test. If one is required,
  # you can enable the server option below.
  pool: Ecto.Adapters.SQL.Sandbox

config :imaginative_restoration, ImaginativeRestorationWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Sa/NkY7mcze1duwlfbIO6Kj9Iqx3JuJMURw1Jl5t0CCopSJwUalMbqMBNDGKvVRR",
  server: false

config :imaginative_restoration, Oban, testing: :inline

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
