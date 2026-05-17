defmodule ImaginativeRestoration.OperatingHours do
  @moduledoc """
  Centralised "should the installation be active right now?" check.

  The art installation runs only on weekdays during business hours and stays
  dark over the holiday break. Both the capture pipeline (in `AppLive`) and
  the camera watchdog consult this module so the gate stays a single source
  of truth.

  Hours are configured under
  `:imaginative_restoration, :operating_hours` as a keyword list. See
  `config/config.exs` for the production values.

  ## Examples

      iex> ImaginativeRestoration.OperatingHours.open?(
      ...>   ~U[2026-05-18 02:00:00Z],
      ...>   timezone: "Australia/Sydney",
      ...>   start_hour: 9, end_hour: 22,
      ...>   weekdays: [1, 2, 3, 4, 5]
      ...> )
      true

      iex> ImaginativeRestoration.OperatingHours.open?(
      ...>   ~U[2026-05-18 23:00:00Z],
      ...>   timezone: "Australia/Sydney",
      ...>   start_hour: 9, end_hour: 22,
      ...>   weekdays: [1, 2, 3, 4, 5]
      ...> )
      false
  """

  @doc """
  Returns `true` when the given UTC `DateTime` falls inside the configured
  operating window. Defaults to `DateTime.utc_now/0`.

  A keyword list can be passed as the second argument to override the
  configured hours — used by tests, not by application code.
  """
  @spec open?(DateTime.t(), keyword()) :: boolean()
  def open?(utc_datetime \\ DateTime.utc_now(), config \\ nil) do
    config = config || Application.fetch_env!(:imaginative_restoration, :operating_hours)

    case DateTime.shift_zone(utc_datetime, Keyword.fetch!(config, :timezone)) do
      {:ok, local} ->
        weekday_open?(local, config) and
          within_hours?(local, config) and
          not blackout?(local, config)

      # If the tz database hasn't loaded yet (boot race) or the zone is
      # mis-configured, fall *open*. Better to capture during an unexpected
      # window than to silently freeze the installation.
      _ ->
        true
    end
  end

  defp weekday_open?(local, config) do
    case Keyword.get(config, :weekdays) do
      nil -> true
      days -> Date.day_of_week(local) in days
    end
  end

  defp within_hours?(local, config) do
    start_hour = Keyword.fetch!(config, :start_hour)
    end_hour = Keyword.fetch!(config, :end_hour)
    local.hour >= start_hour and local.hour < end_hour
  end

  defp blackout?(local, config) do
    config
    |> Keyword.get(:blackout_ranges, [])
    |> Enum.any?(&in_range?(local, &1))
  end

  defp in_range?(%DateTime{month: month, day: day}, {{start_month, start_day}, {end_month, end_day}}) do
    start_md = {start_month, start_day}
    end_md = {end_month, end_day}
    current = {month, day}

    if start_md <= end_md do
      current >= start_md and current <= end_md
    else
      # Range wraps the year boundary (e.g. Dec 21 → Jan 6).
      current >= start_md or current <= end_md
    end
  end
end
