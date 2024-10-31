defmodule ImaginativeRestorationWeb.ConfigLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

  import ImaginativeRestorationWeb.AppComponents

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative flex items-center justify-center size-full">
      <.webcam_capture class="h-[300px]" capture_box={@capture_box} capture_interval={10_000} />
      <img src={@frame} />
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, frame: nil, capture_box: nil)}
  end

  @impl true
  def handle_params(%{"capture_box" => capture_box}, _path, socket) do
    capture_box = capture_box |> String.split(",") |> Enum.map(&String.to_integer/1)
    {:noreply, assign(socket, capture_box: capture_box)}
  end

  @impl true
  def handle_event("webcam_frame", %{"frame" => dataurl}, socket) do
    {:noreply, assign(socket, :frame, dataurl)}
  end
end
