defmodule Mix.Tasks.ImaginativeRestoration.MigrateImages do
  @moduledoc """
  One-shot backfill that converts legacy text data-URL columns
  (`raw`, `processed`) into the new binary blob columns
  (`raw_data`, `processed_data`, `thumbnail`).

  For each row:

    * if `raw_data` is empty and `raw` holds a data URL, decode the base64
      and store the JPEG bytes
    * if `processed_data` is empty and `processed` holds a data URL, decode
      and re-encode as AVIF
    * if `thumbnail` is empty and a processed image is available, generate
      a 300 px AVIF thumbnail

  Idempotent — already-migrated rows are skipped, so the task is safe to
  re-run if interrupted.

  ## Options

    * `--concurrency N` — number of rows to process in parallel (default 4).
      Each row triggers an AVIF encode, which is CPU-bound; tune for the
      target machine.
    * `--limit N` — process at most N rows. Handy for a smoke test before
      running over the whole table.

  ## Usage

      mix imaginative_restoration.migrate_images
      mix imaginative_restoration.migrate_images --concurrency 2 --limit 10
  """
  use Mix.Task

  alias ImaginativeRestoration.Sketches.Sketch
  alias ImaginativeRestoration.Utils

  require Ash.Query

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [concurrency: :integer, limit: :integer]
      )

    Mix.Task.run("app.start")

    concurrency = Keyword.get(opts, :concurrency, 4)
    limit = Keyword.get(opts, :limit)

    rows = pending_rows(limit)
    total = length(rows)

    Mix.shell().info("Backfilling #{total} row(s) with concurrency=#{concurrency}")

    {ok, errors} =
      rows
      |> Task.async_stream(
        &migrate_one/1,
        max_concurrency: concurrency,
        ordered: false,
        timeout: :infinity
      )
      |> Enum.reduce({0, []}, fn
        {:ok, {:ok, id}}, {ok, errs} ->
          Mix.shell().info("  ✓ sketch #{id}")
          {ok + 1, errs}

        {:ok, {:error, id, reason}}, {ok, errs} ->
          Mix.shell().error("  ✗ sketch #{id}: #{inspect(reason)}")
          {ok, [{id, reason} | errs]}
      end)

    Mix.shell().info("Done: #{ok} migrated, #{length(errors)} failed")
    if errors != [], do: exit({:shutdown, 1})
  end

  defp pending_rows(limit) do
    query =
      Sketch
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(
        (is_nil(raw_data) and not is_nil(raw)) or
          (is_nil(processed_data) and not is_nil(processed)) or
          (is_nil(thumbnail) and (not is_nil(processed_data) or not is_nil(processed)))
      )
      |> Ash.Query.sort(inserted_at: :asc)

    query =
      if limit do
        Ash.Query.limit(query, limit)
      else
        query
      end

    Ash.read!(query)
  end

  defp migrate_one(sketch) do
    sketch
    |> Ash.Changeset.for_update(:backfill_images, %{})
    |> backfill_raw_data(sketch)
    |> backfill_processed_data(sketch)
    |> backfill_thumbnail(sketch)
    |> Ash.update()
    |> case do
      {:ok, _} -> {:ok, sketch.id}
      {:error, reason} -> {:error, sketch.id, reason}
    end
  rescue
    e -> {:error, sketch.id, Exception.message(e)}
  end

  defp backfill_raw_data(changeset, %Sketch{raw_data: nil, raw: "data:image/" <> _ = dataurl}) do
    Ash.Changeset.force_change_attribute(changeset, :raw_data, Utils.decode_dataurl!(dataurl))
  end

  defp backfill_raw_data(changeset, _sketch), do: changeset

  defp backfill_processed_data(changeset, %Sketch{processed_data: nil, processed: "data:image/" <> _ = dataurl}) do
    avif = dataurl |> Utils.decode_dataurl!() |> Utils.to_avif!()
    Ash.Changeset.force_change_attribute(changeset, :processed_data, avif)
  end

  defp backfill_processed_data(changeset, _sketch), do: changeset

  defp backfill_thumbnail(changeset, %Sketch{thumbnail: nil} = sketch) do
    case thumbnail_source(changeset, sketch) do
      nil -> changeset
      bytes -> Ash.Changeset.force_change_attribute(changeset, :thumbnail, Utils.to_thumbnail_avif!(bytes))
    end
  end

  defp backfill_thumbnail(changeset, _sketch), do: changeset

  defp thumbnail_source(changeset, sketch) do
    cond do
      pd = Ash.Changeset.get_attribute(changeset, :processed_data) -> pd
      is_binary(sketch.processed_data) -> sketch.processed_data
      is_binary(sketch.processed) -> Utils.decode_dataurl!(sketch.processed)
      true -> nil
    end
  end
end
