defmodule ImaginativeRestorationWeb.IndexLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class=" flex items-center justify-center h-full">
      <div class="relative w-full max-w-[calc(100vh*4/3)] aspect-[4/3]">
        <video autoplay loop muted class="w-full h-full object-contain">
          <source
            src="https://fly.storage.tigris.dev/imaginative-restoration-sketches/IMGRES_FirstRoughEdit_V1.0_DH_11.09.24.mp4"
            type="video/mp4"
          /> Your browser does not support the video tag.
        </video>
        <div class="absolute top-8 left-8 flex gap-8">
          <video
            id="video"
            phx-hook="WebcamStream"
            phx-data-capture-size="512"
            class="size-[240px] object-cover"
          >
            Video stream not available.
          </video>
          <img :if={@sketch} src={@sketch.raw} class="size-[240px] object-cover" />
          <img :if={@sketch} src={@sketch.cropped} class="size-[240px] object-contain" />
          <img :if={@sketch} src={@sketch.processed} class="size-[240px] object-cover" />
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, sketch: nil)}
  end

  @impl true
  def handle_event("webcam_frame", %{"frame" => dataurl}, socket) do
    pid = self()

    # spawn the task which will communicate back to self() via :update_sketch messages
    Task.start(fn ->
      sketch = ImaginativeRestoration.Sketches.init!(dataurl)
      send(pid, {:update_sketch, sketch})
      sketch = ImaginativeRestoration.Sketches.process!(sketch)
      send(pid, {:update_sketch, sketch})
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:update_sketch, sketch}, socket) do
    {:noreply, assign(socket, sketch: sketch)}
  end
end
