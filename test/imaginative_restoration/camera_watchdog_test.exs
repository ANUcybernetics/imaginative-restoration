defmodule ImaginativeRestoration.CameraWatchdogTest do
  # Not async: the supervised watchdog is a named singleton. Tests stop it for
  # the duration of each scenario and restart it via the supervisor on exit.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias ImaginativeRestoration.CameraWatchdog

  setup do
    # The application-supervised watchdog uses production timings; replace it
    # with a test instance whose silence threshold we can saturate quickly.
    stop_supervised_watchdog!()

    {:ok, pid} =
      start_supervised({CameraWatchdog, silence_threshold: 50, check_interval: 10, auto_check?: false})

    on_exit(fn ->
      # Restart the application-supervised watchdog so other tests find it.
      _ = Supervisor.restart_child(ImaginativeRestoration.Supervisor, CameraWatchdog)
    end)

    %{pid: pid}
  end

  describe "heartbeat/0" do
    test "records the most recent heartbeat" do
      assert %{last_heartbeat: nil, warned?: false} = CameraWatchdog.state()

      CameraWatchdog.heartbeat()

      assert %{last_heartbeat: t} = CameraWatchdog.state()
      assert is_integer(t)
    end
  end

  describe "check_now/0" do
    test "warns when silence has exceeded the threshold during operating hours" do
      log =
        capture_log(fn ->
          CameraWatchdog.heartbeat()
          Process.sleep(80)
          CameraWatchdog.check_now()
        end)

      assert log =~ "No camera frames"
      assert %{warned?: true} = CameraWatchdog.state()
    end

    test "stays quiet when recent heartbeat keeps it within threshold" do
      log =
        capture_log(fn ->
          CameraWatchdog.heartbeat()
          CameraWatchdog.check_now()
        end)

      refute log =~ "No camera frames"
      assert %{warned?: false} = CameraWatchdog.state()
    end

    test "logs once and stays quiet on subsequent checks until heartbeat returns" do
      capture_log(fn ->
        CameraWatchdog.heartbeat()
        Process.sleep(80)
        CameraWatchdog.check_now()
      end)

      second_log =
        capture_log(fn ->
          CameraWatchdog.check_now()
        end)

      refute second_log =~ "No camera frames"
    end

    test "logs a 'resumed' message when heartbeat returns after a warning" do
      previous_level = Logger.level()
      Logger.configure(level: :info)
      on_exit(fn -> Logger.configure(level: previous_level) end)

      capture_log(fn ->
        Process.sleep(80)
        CameraWatchdog.check_now()
      end)

      resumed_log = capture_log(fn -> CameraWatchdog.heartbeat() end)

      assert resumed_log =~ "Camera frames resumed"
      assert %{warned?: false} = CameraWatchdog.state()
    end

    test "stays quiet outside operating hours" do
      # Force operating hours to closed (everything blacklisted) for this test.
      prev = Application.get_env(:imaginative_restoration, :operating_hours)

      Application.put_env(
        :imaginative_restoration,
        :operating_hours,
        Keyword.put(prev, :blackout_ranges, [{{1, 1}, {12, 31}}])
      )

      log =
        capture_log(fn ->
          Process.sleep(80)
          CameraWatchdog.check_now()
        end)

      refute log =~ "No camera frames"
      assert %{warned?: false} = CameraWatchdog.state()
    after
      # Restore.
      Application.put_env(
        :imaginative_restoration,
        :operating_hours,
        :imaginative_restoration
        |> Application.get_env(:operating_hours)
        |> Keyword.put(:blackout_ranges, [])
      )
    end
  end

  defp stop_supervised_watchdog! do
    case Process.whereis(CameraWatchdog) do
      nil -> :ok
      _pid -> :ok = Supervisor.terminate_child(ImaginativeRestoration.Supervisor, CameraWatchdog)
    end
  end
end
