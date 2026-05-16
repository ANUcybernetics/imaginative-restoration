defmodule Mix.Tasks.ImaginativeRestoration.MigrateImages do
  @moduledoc """
  One-shot backfill that converts legacy text data-URL columns
  (`raw`, `processed`) into the new binary blob columns
  (`raw_data`, `processed_data`, `thumbnail`).

  ## Options

    * `--concurrency N` — number of rows to process in parallel (default 4)
    * `--limit N` — process at most N rows (smoke-test mode)
    * `--batch-size N` — rows per query batch (default 100)

  ## Usage

      mix imaginative_restoration.migrate_images
      mix imaginative_restoration.migrate_images --concurrency 8 --limit 100
  """
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [concurrency: :integer, limit: :integer, batch_size: :integer]
      )

    Mix.Task.run("app.start")
    ImaginativeRestoration.MigrateImages.run(opts)
  end
end
