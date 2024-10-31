defmodule ImaginativeRestorationWeb.ConfigLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative flex items-center justify-center size-full">
      <div class="h-[300px] relative">
        <video
          id="video"
          phx-hook="WebcamStream"
          data-capture-box={@capture_box && Jason.encode!(@capture_box)}
          data-capture-interval="1000"
          class="h-full w-auto"
        >
          Webcam video stream not available.
        </video>
        <svg class="absolute inset-0 w-full h-full pointer-events-none">
          <line
            id="progress-line"
            x1="0"
            y1="5"
            x2="100%"
            y2="5"
            stroke-width="10"
            stroke="#00ff00"
            transform-origin="center"
          />
          <rect id="flash-overlay" x="0" y="0" width="100%" height="100%" fill="#ffffff" opacity="0" />
        </svg>
      </div>
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
