defmodule ImaginativeRestoration.Sketches.Sweeper do
  @moduledoc """
  Periodically reconciles in-flight sketches against Replicate.

  For each sketch in `:generating` or `:removing_background` that hasn't moved
  for `@stale_after_seconds`, the sweeper fetches the actual prediction status
  from Replicate and hands the payload to `Sketches.Advance`. That dispatch
  drives the state machine forward (or applies the retry-or-fail logic)
  exactly as if a webhook had arrived.

  This is a backstop for lost webhooks (network glitches, mid-deploy restarts,
  rejected signatures). Unlike the previous time-only sweep, it never kills a
  prediction that Replicate is still working on — it only acts when Replicate
  itself reports a terminal status.
  """
  use GenServer

  alias ImaginativeRestoration.AI.Replicate
  alias ImaginativeRestoration.Sketches.Advance
  alias ImaginativeRestoration.Sketches.Sketch

  require Ash.Query
  require Logger

  @default_sweep_interval_ms :timer.seconds(30)
  @stale_after_seconds 60

  defp sweep_interval_ms do
    Application.get_env(:imaginative_restoration, :sweeper_interval_ms, @default_sweep_interval_ms)
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Run the sweep synchronously. Used in tests."
  def sweep_now, do: GenServer.call(__MODULE__, :sweep, :timer.seconds(30))

  @impl true
  def init(_opts) do
    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    do_sweep()
    schedule_sweep()
    {:noreply, state}
  end

  @impl true
  def handle_call(:sweep, _from, state) do
    {:reply, do_sweep(), state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, sweep_interval_ms())

  defp do_sweep do
    cutoff = DateTime.add(DateTime.utc_now(), -@stale_after_seconds, :second)

    case fetch_stale(cutoff) do
      {:ok, stale} ->
        Enum.reduce(stale, %{advanced: 0, retried: 0, failed: 0, still_running: 0, ignored: 0, errored: 0}, fn sketch, acc ->
          outcome = reconcile(sketch)
          Map.update!(acc, outcome, &(&1 + 1))
        end)

      {:error, reason} ->
        Logger.warning("Sweep skipped: #{inspect(reason)}")
        %{}
    end
  end

  defp reconcile(%Sketch{prediction_id: nil} = sketch) do
    Logger.warning("Sketch #{sketch.id}: stale in #{sketch.state} with no prediction_id; skipping")
    :ignored
  end

  defp reconcile(%Sketch{} = sketch) do
    case Replicate.get_prediction(sketch.prediction_id) do
      {:ok, payload} ->
        case Advance.advance(sketch, payload) do
          {:ok, outcome} ->
            log_outcome(sketch, payload, outcome)
            outcome

          {:error, reason} ->
            Logger.warning("Sketch #{sketch.id}: advance/2 errored: #{inspect(reason)}")
            :errored
        end

      {:error, reason} ->
        Logger.warning(
          "Sketch #{sketch.id}: failed to fetch prediction #{sketch.prediction_id}: #{inspect(reason)}"
        )

        :errored
    end
  end

  defp log_outcome(sketch, payload, outcome) when outcome in [:advanced, :retried, :failed] do
    Logger.info(
      "Sweeper reconciled sketch #{sketch.id} (was #{sketch.state}, prediction status=#{payload["status"]}): #{outcome}"
    )
  end

  defp log_outcome(_sketch, _payload, _outcome), do: :ok

  # If the DB pool is saturated (e.g. a backfill or burst of LV traffic is in
  # flight), the sweep's checkout would block and crash the GenServer. The
  # sweep is best-effort housekeeping; skip and try again next tick.
  defp fetch_stale(cutoff) do
    {:ok,
     Sketch
     |> Ash.Query.for_read(:read)
     |> Ash.Query.filter(state in [:generating, :removing_background] and updated_at < ^cutoff)
     |> Ash.read!(timeout: :timer.seconds(5))}
  rescue
    e -> {:error, Exception.message(e)}
  end
end
