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

  The sweep walks the table in `inserted_at DESC` order with a cursor, so
  each batch query is O(batch_size), not O(rows-already-touched). Rows that
  are already fully populated are skipped without a DB write. Rows that
  fail (typically `Database busy` from Sweeper contention) are collected
  and retried at the end.

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
    * `:batch_size` — rows pulled per query batch (default 100)
    * `:retry?` — when true (default), do a second pass over rows that
      failed transiently during the main sweep
  """
  @spec run(keyword()) :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  def run(opts \\ []) do
    Application.ensure_all_started(:imaginative_restoration)

    concurrency = Keyword.get(opts, :concurrency, 4)
    limit = Keyword.get(opts, :limit)
    batch_size = Keyword.get(opts, :batch_size, 100)
    retry? = Keyword.get(opts, :retry?, true)

    Logger.info("Backfill starting: concurrency=#{concurrency} batch_size=#{batch_size}")

    state = %{
      ok: 0,
      skipped: 0,
      failed_ids: [],
      cursor: nil,
      concurrency: concurrency,
      batch_size: batch_size,
      limit: limit
    }

    state = backfill_loop(state)

    Logger.info(
      "Sweep done: #{state.ok} migrated, #{state.skipped} skipped, #{length(state.failed_ids)} failed"
    )

    final =
      if retry? and state.failed_ids != [] do
        retry_failed(state.failed_ids, concurrency)
      else
        {0, length(state.failed_ids)}
      end

    {retry_ok, still_failed} = final

    Logger.info(
      "Backfill done: #{state.ok + retry_ok} migrated, #{state.skipped} skipped, #{still_failed} failed"
    )

    {state.ok + retry_ok, state.skipped, still_failed}
  end

  defp backfill_loop(%{limit: limit, ok: ok, skipped: skipped, failed_ids: failed_ids} = state)
       when not is_nil(limit) and ok + skipped + length(failed_ids) >= limit do
    state
  end

  defp backfill_loop(state) do
    take = batch_take(state)

    case pending_rows(take, state.cursor) do
      [] ->
        state

      rows ->
        {batch_ok, batch_skipped, batch_failed_ids} = process_batch(rows, state.concurrency)
        next_cursor = rows |> List.last() |> Map.fetch!(:inserted_at)

        new_state = %{
          state
          | ok: state.ok + batch_ok,
            skipped: state.skipped + batch_skipped,
            failed_ids: state.failed_ids ++ batch_failed_ids,
            cursor: next_cursor
        }

        Logger.info(
          "Progress: #{new_state.ok} migrated, #{new_state.skipped} skipped, #{length(new_state.failed_ids)} failed (cursor=#{next_cursor})"
        )

        backfill_loop(new_state)
    end
  end

  defp batch_take(%{limit: nil, batch_size: bs}), do: bs

  defp batch_take(%{limit: limit, ok: ok, skipped: skipped, failed_ids: f, batch_size: bs}) do
    min(bs, max(0, limit - ok - skipped - length(f)))
  end

  defp process_batch(rows, concurrency) do
    rows
    |> Task.async_stream(&migrate_one/1,
      max_concurrency: concurrency,
      ordered: false,
      timeout: :infinity
    )
    |> Enum.reduce({0, 0, []}, fn
      {:ok, :skipped}, {ok, skipped, failed_ids} ->
        {ok, skipped + 1, failed_ids}

      {:ok, {:ok, _id}}, {ok, skipped, failed_ids} ->
        {ok + 1, skipped, failed_ids}

      {:ok, {:error, id, reason}}, {ok, skipped, failed_ids} ->
        Logger.error("Sketch #{id} failed: #{inspect(reason)}")
        {ok, skipped, [id | failed_ids]}
    end)
  end

  defp pending_rows(0, _cursor), do: []

  defp pending_rows(limit, nil) do
    Sketch
    |> Ash.Query.for_read(:read)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.read!()
  end

  defp pending_rows(limit, cursor) do
    Sketch
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(inserted_at < ^cursor)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.read!()
  end

  defp retry_failed([], _concurrency), do: {0, 0}

  defp retry_failed(ids, concurrency) do
    Logger.info("Retrying #{length(ids)} failed row(s)")

    rows = Sketch |> Ash.Query.for_read(:read) |> Ash.Query.filter(id in ^ids) |> Ash.read!()
    {ok, _skipped, failed_ids} = process_batch(rows, concurrency)
    {ok, length(failed_ids)}
  end

  defp migrate_one(sketch) do
    if needs_backfill?(sketch) do
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
    else
      :skipped
    end
  rescue
    e -> {:error, sketch.id, Exception.message(e)}
  end

  defp needs_backfill?(sketch) do
    needs_raw_data?(sketch) or needs_processed_data?(sketch) or needs_thumbnail?(sketch)
  end

  defp needs_raw_data?(%Sketch{raw_data: nil, raw: "data:image/" <> _}), do: true
  defp needs_raw_data?(_), do: false

  defp needs_processed_data?(%Sketch{processed_data: nil, processed: "data:image/" <> _}), do: true
  defp needs_processed_data?(_), do: false

  defp needs_thumbnail?(%Sketch{thumbnail: nil, processed_data: pd}) when is_binary(pd), do: true
  defp needs_thumbnail?(%Sketch{thumbnail: nil, processed: "data:image/" <> _}), do: true
  defp needs_thumbnail?(_), do: false

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
