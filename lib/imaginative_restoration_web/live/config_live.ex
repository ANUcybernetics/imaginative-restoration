defmodule ImaginativeRestorationWeb.ConfigLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

  import ImaginativeRestorationWeb.AppComponents

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative flex items-center justify-center size-full">
      <.webcam_capture class="h-[300px]" capture_interval={10_000} />
      <div class="relative">
        <img src={@frame} />
        <div class="absolute inset-0 flex items-center justify-center">
          <span class="text-4xl px-2 py-1 text-white backdrop-blur-md rounded-sm">label</span>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, frame: nil), layout: {ImaginativeRestorationWeb.Layouts, :canvas}}
  end

  @impl true
  def handle_event("webcam_frame", %{"frame" => dataurl}, socket) do
    {:noreply, assign(socket, :frame, dataurl)}
  end
end
