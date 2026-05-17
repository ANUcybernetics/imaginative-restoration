defmodule ImaginativeRestoration.CameraWatchdog do
  @moduledoc """
  Logs a warning when the camera goes silent during operating hours.

  The capture pipeline is push-only: the kiosk's browser sends a frame every
  second over the LiveView socket. If the kiosk reboots, the LV socket drops,
  or the camera dies mid-day, nothing in the app crashes loudly — you only
  notice by looking at the display. This watchdog converts that silent
  failure into a log line so it can be surfaced by ops monitoring.

  Outside operating hours, silence is expected and the watchdog stays quiet.
  """
  use GenServer

  alias ImaginativeRestoration.OperatingHours

  require Logger

  @check_interval to_timeout(minute: 1)
  @silence_threshold to_timeout(second: 90)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Called by `AppLive` whenever a webcam frame arrives. Resets the silence
  timer.
  """
  def heartbeat do
    GenServer.cast(__MODULE__, :heartbeat)
  end

  @doc """
  Returns the current internal state. Used by tests.
  """
  def state, do: GenServer.call(__MODULE__, :state)

  @doc """
  Forces a check immediately rather than waiting for the next tick. Used by
  tests.
  """
  def check_now, do: GenServer.call(__MODULE__, :check_now)

  @impl true
  def init(opts) do
    silence_threshold = Keyword.get(opts, :silence_threshold, @silence_threshold)
    check_interval = Keyword.get(opts, :check_interval, @check_interval)

    if Keyword.get(opts, :auto_check?, true), do: schedule_check(check_interval)

    {:ok,
     %{
       last_heartbeat: nil,
       warned?: false,
       silence_threshold: silence_threshold,
       check_interval: check_interval,
       auto_check?: Keyword.get(opts, :auto_check?, true)
     }}
  end

  @impl true
  def handle_cast(:heartbeat, state) do
    if state.warned? do
      Logger.info("Camera frames resumed")
    end

    {:noreply, %{state | last_heartbeat: monotonic_ms(), warned?: false}}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:check_now, _from, state) do
    {:reply, :ok, do_check(state)}
  end

  @impl true
  def handle_info(:check, state) do
    if state.auto_check?, do: schedule_check(state.check_interval)
    {:noreply, do_check(state)}
  end

  defp do_check(state) do
    cond do
      not OperatingHours.open?() ->
        # Don't warn if silence is expected (kiosk asleep, holiday, weekend).
        # Reset the warned flag so we don't spuriously log "resumed" when
        # heartbeats return the next morning.
        %{state | warned?: false}

      silent_too_long?(state) and not state.warned? ->
        Logger.warning("No camera frames for #{silence_seconds(state)}s during operating hours — kiosk may be offline")

        %{state | warned?: true}

      true ->
        state
    end
  end

  defp silent_too_long?(%{last_heartbeat: nil}), do: true

  defp silent_too_long?(%{last_heartbeat: t, silence_threshold: threshold}) do
    monotonic_ms() - t > threshold
  end

  defp silence_seconds(%{last_heartbeat: nil}), do: "(never)"
  defp silence_seconds(%{last_heartbeat: t}), do: div(monotonic_ms() - t, 1000)

  defp schedule_check(interval), do: Process.send_after(self(), :check, interval)

  defp monotonic_ms, do: System.monotonic_time(:millisecond)
end
