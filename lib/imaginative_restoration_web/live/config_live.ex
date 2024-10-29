defmodule ImaginativeRestorationWeb.ConfigLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

  alias ImaginativeRestoration.AI.Utils

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative flex items-center justify-center size-full">
      <video
        id="video"
        phx-hook="WebcamStream"
        data-capture-box={@capture_box && Jason.encode!(@capture_box)}
        data-capture-interval="1000"
      >
        Video stream not available.
      </video>
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
