defmodule ImaginativeRestorationWeb.IndexLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

  import ImaginativeRestorationWeb.AppComponents

  alias ImaginativeRestoration.AI.Utils
  alias ImaginativeRestoration.Sketches.Sketch

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative flex items-center justify-center size-full">
      <div class="w-full max-w-[calc(100vh*4/3)] aspect-[4/3]">
        <div class="relative w-full h-full">
          <canvas id="boid-canvas" phx-hook="BoidCanvas" class="w-full h-full object-contain">
          </canvas>
        </div>
        <div class="absolute top-8 left-8 flex gap-8 h-[200px]">
          <.webcam_capture capture_interval={30_000} />
          <img :if={@sketch} src={@sketch.raw} class="h-full w-auto object-contain" />
          <div :if={@sketch} class="relative h-full">
            <img src={@sketch.cropped} class="h-full w-auto object-contain" />
            <div class="absolute inset-0 flex items-center justify-center">
              <span class="text-black text-lg font-bold"><%= @sketch.label %></span>
            </div>
          </div>
          <img :if={@sketch} src={@sketch.processed} class="h-full w-auto object-contain" />
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

    if not Utils.changed_recently?(5) do
      Logger.info("Skipping frame processing")
    end

    # spawn the task which will communicate back to self() via :update_sketch messages
    Task.start(fn ->
      dataurl
      |> ImaginativeRestoration.Sketches.init!()
      |> send_update_sketch_message(pid)
      |> ImaginativeRestoration.Sketches.crop_and_set_prompt!()
      |> send_update_sketch_message(pid)
      |> ImaginativeRestoration.Sketches.process!()
      |> send_update_sketch_message(pid)
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:update_sketch, %Sketch{processed: processed} = sketch}, socket) when not is_nil(processed) do
    # Push event to client when we have a processed sketch
    {:noreply,
     socket
     |> assign(sketch: sketch)
     |> push_event("new_boid", %{id: sketch.id, dataurl: processed})}
  end

  @impl true
  def handle_info({:update_sketch, sketch}, socket) do
    {:noreply, assign(socket, sketch: sketch)}
  end

  defp send_update_sketch_message(sketch, pid) do
    send(pid, {:update_sketch, sketch})

    # pass the sketch back out; useful for pipelining
    sketch
  end
end
