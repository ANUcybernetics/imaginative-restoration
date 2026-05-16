defmodule ImaginativeRestoration.MigrateImages do
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

  Callable from a release with:

      ./bin/imaginative_restoration eval 'ImaginativeRestoration.MigrateImages.run(concurrency: 8)'
  """

  alias ImaginativeRestoration.Sketches.Sketch
  alias ImaginativeRestoration.Utils

  require Ash.Query
  require Logger

  @doc """
  Runs the backfill.

  Options:
    * `:concurrency` — number of rows to encode in parallel (default 4)
    * `:limit` — process at most N rows (handy for smoke tests)
    * `:batch_size` — rows pulled per query batch (default 100); keeps memory
      bounded when the table is huge
  """
  @spec run(keyword()) :: {non_neg_integer(), non_neg_integer()}
  def run(opts \\ []) do
    Application.ensure_all_started(:imaginative_restoration)

    concurrency = Keyword.get(opts, :concurrency, 4)
    limit = Keyword.get(opts, :limit)
    batch_size = Keyword.get(opts, :batch_size, 100)

    Logger.info("Backfill starting: concurrency=#{concurrency} batch_size=#{batch_size}")

    {ok, failed} = backfill_loop(concurrency, batch_size, limit, 0, 0)

    Logger.info("Backfill done: #{ok} migrated, #{failed} failed")
    {ok, failed}
  end

  defp backfill_loop(_concurrency, _batch_size, limit, ok, failed) when not is_nil(limit) and ok + failed >= limit do
    {ok, failed}
  end

  defp backfill_loop(concurrency, batch_size, limit, ok, failed) do
    remaining = if limit, do: max(0, limit - ok - failed), else: nil
    take = if remaining, do: min(batch_size, remaining), else: batch_size

    case pending_rows(take) do
      [] ->
        {ok, failed}

      rows ->
        {batch_ok, batch_failed} = process_batch(rows, concurrency)
        new_ok = ok + batch_ok
        new_failed = failed + batch_failed
        Logger.info("Progress: #{new_ok} migrated, #{new_failed} failed")
        backfill_loop(concurrency, batch_size, limit, new_ok, new_failed)
    end
  end

  defp process_batch(rows, concurrency) do
    rows
    |> Task.async_stream(&migrate_one/1,
      max_concurrency: concurrency,
      ordered: false,
      timeout: :infinity
    )
    |> Enum.reduce({0, 0}, fn
      {:ok, {:ok, _id}}, {ok, failed} -> {ok + 1, failed}
      {:ok, {:error, id, reason}}, {ok, failed} ->
        Logger.error("Sketch #{id} failed: #{inspect(reason)}")
        {ok, failed + 1}
    end)
  end

  defp pending_rows(limit) do
    Sketch
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(
      (is_nil(raw_data) and not is_nil(raw)) or
        (is_nil(processed_data) and not is_nil(processed)) or
        (is_nil(thumbnail) and (not is_nil(processed_data) or not is_nil(processed)))
    )
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.Query.limit(limit)
    |> Ash.read!()
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
