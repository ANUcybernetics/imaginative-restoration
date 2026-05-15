defmodule ImaginativeRestoration.Sketches.Sweeper do
  @moduledoc """
  Periodically fails sketches that have been stuck in a non-terminal state for
  too long.

  A sketch can get stuck if Replicate never delivers the webhook (network
  glitch, mid-deploy restart, etc.). Without this sweep, the LiveView's
  `current_sketch_id` would never clear and no new frames would be submitted.
  """
  use GenServer

  alias ImaginativeRestoration.Sketches
  alias ImaginativeRestoration.Sketches.Sketch

  require Ash.Query
  require Logger

  @sweep_interval_ms :timer.seconds(60)
  @stuck_after_seconds 300

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Run the sweep synchronously. Used in tests."
  def sweep_now, do: GenServer.call(__MODULE__, :sweep)

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

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval_ms)

  defp do_sweep do
    cutoff = DateTime.add(DateTime.utc_now(), -@stuck_after_seconds, :second)

    stuck =
      Sketch
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(state in [:generating, :removing_background] and updated_at < ^cutoff)
      |> Ash.read!()

    Enum.each(stuck, fn sketch ->
      Logger.warning(
        "Failing stuck sketch #{sketch.id} (state=#{sketch.state}, updated_at=#{sketch.updated_at})"
      )

      Sketches.fail(sketch, "Timed out after #{@stuck_after_seconds}s in state #{sketch.state}")
    end)

    length(stuck)
  end
end
