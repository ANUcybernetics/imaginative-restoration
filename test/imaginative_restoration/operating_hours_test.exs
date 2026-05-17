defmodule ImaginativeRestoration.OperatingHoursTest do
  use ExUnit.Case, async: true

  alias ImaginativeRestoration.OperatingHours

  @sydney_config [
    timezone: "Australia/Sydney",
    start_hour: 9,
    end_hour: 22,
    weekdays: [1, 2, 3, 4, 5],
    blackout_ranges: [{{12, 21}, {1, 6}}]
  ]

  describe "open?/2 — weekday hours" do
    test "open during weekday business hours" do
      # 2026-05-18 02:00 UTC = Mon 12:00 AEST → open
      assert OperatingHours.open?(~U[2026-05-18 02:00:00Z], @sydney_config)
    end

    test "open exactly at start hour" do
      # 2026-05-17 23:00 UTC = Mon 2026-05-18 09:00 AEST → open
      assert OperatingHours.open?(~U[2026-05-17 23:00:00Z], @sydney_config)
    end

    test "closed one minute before start hour" do
      # 2026-05-17 22:59 UTC = Mon 08:59 AEST → closed
      refute OperatingHours.open?(~U[2026-05-17 22:59:00Z], @sydney_config)
    end

    test "open one minute before end hour" do
      # 2026-05-18 11:59 UTC = Mon 21:59 AEST → open
      assert OperatingHours.open?(~U[2026-05-18 11:59:00Z], @sydney_config)
    end

    test "closed exactly at end hour" do
      # 2026-05-18 12:00 UTC = Mon 22:00 AEST → closed
      refute OperatingHours.open?(~U[2026-05-18 12:00:00Z], @sydney_config)
    end
  end

  describe "open?/2 — weekend" do
    test "closed on Saturday" do
      # 2026-05-16 02:00 UTC = Sat 12:00 AEST → closed
      refute OperatingHours.open?(~U[2026-05-16 02:00:00Z], @sydney_config)
    end

    test "closed on Sunday" do
      # 2026-05-17 02:00 UTC = Sun 12:00 AEST → closed
      refute OperatingHours.open?(~U[2026-05-17 02:00:00Z], @sydney_config)
    end
  end

  describe "open?/2 — blackout periods" do
    test "closed during late-December blackout" do
      # 2025-12-22 02:00 UTC = Mon 13:00 AEDT → closed (blackout)
      refute OperatingHours.open?(~U[2025-12-22 02:00:00Z], @sydney_config)
    end

    test "closed during early-January blackout" do
      # 2026-01-05 02:00 UTC = Mon 13:00 AEDT → closed (blackout)
      refute OperatingHours.open?(~U[2026-01-05 02:00:00Z], @sydney_config)
    end

    test "open the day after the blackout ends" do
      # 2026-01-07 02:00 UTC = Wed 13:00 AEDT → open
      assert OperatingHours.open?(~U[2026-01-07 02:00:00Z], @sydney_config)
    end

    test "non-wrapping blackout range" do
      config = Keyword.put(@sydney_config, :blackout_ranges, [{{6, 1}, {6, 30}}])

      # 2026-06-15 02:00 UTC = Mon 12:00 AEST → in range
      refute OperatingHours.open?(~U[2026-06-15 02:00:00Z], config)

      # 2026-07-06 02:00 UTC = Mon 12:00 AEST → outside range
      assert OperatingHours.open?(~U[2026-07-06 02:00:00Z], config)
    end
  end

  describe "open?/2 — DST handling" do
    test "honours AEDT (UTC+11) during summer" do
      # 2025-12-01 22:00 UTC = Tue 09:00 AEDT → open
      assert OperatingHours.open?(~U[2025-12-01 22:00:00Z], @sydney_config)
      # 2025-12-01 21:59 UTC = Tue 08:59 AEDT → closed
      refute OperatingHours.open?(~U[2025-12-01 21:59:00Z], @sydney_config)
    end

    test "honours AEST (UTC+10) during winter" do
      # 2026-06-01 23:00 UTC = Tue 09:00 AEST → open
      assert OperatingHours.open?(~U[2026-06-01 23:00:00Z], @sydney_config)
      # 2026-06-01 22:59 UTC = Tue 08:59 AEST → closed
      refute OperatingHours.open?(~U[2026-06-01 22:59:00Z], @sydney_config)
    end
  end

  describe "open?/2 — fallback behaviour" do
    test "returns true when timezone resolution fails" do
      bad_config = Keyword.put(@sydney_config, :timezone, "Mars/Olympus_Mons")
      assert OperatingHours.open?(~U[2026-05-18 02:00:00Z], bad_config)
    end
  end
end
