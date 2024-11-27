defmodule ImaginativeRestorationWeb.AppLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

  import ImaginativeRestorationWeb.AppComponents

  alias ImaginativeRestoration.Sketches.Sketch
  alias ImaginativeRestoration.Utils
  alias Phoenix.Socket.Broadcast

  require Ash.Query
  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <audio id="background-audio" autoplay loop>
      <source
        src="https://fly.storage.tigris.dev/imaginative-restoration-sketches/592086__soundflakes__soundflakes-horizon-of-the-unknown.mp3"
        type="audio/mp3"
      />
    </audio>
    <div class="relative flex items-center justify-center size-full">
      <div class="w-full max-w-[calc(100vh*4/3)] aspect-[4/3]">
        <div class="relative w-full h-full">
          <canvas id="boid-canvas" phx-hook="SketchCanvas" class="w-full h-full object-contain">
          </canvas>
        </div>
        <div :if={@capture} class="absolute top-8 left-8 flex gap-8 h-[200px] backdrop-blur-md">
          <.webcam_capture capture_interval={30_000} />
          <div :if={@sketch} class="relative">
            <img
              src={if pipeline_phase(@sketch) == :labelling, do: @sketch.raw, else: @sketch.cropped}
              class={[
                "h-full w-auto object-contain",
                pipeline_phase(@sketch) != :completed && "sketch-processing"
              ]}
            />
            <span
              :if={@sketch.label}
              class="absolute left-1/2 bottom-5 -translate-x-1/2 text-4xl font-lacquer font-semibold px-2 py-1 text-[#8B2E15] backdrop-blur-md rounded-sm"
            >
              <%= @sketch.label %>
            </span>
          </div>
          <img
            :if={@sketch && @sketch.processed}
            src={@sketch.processed}
            class="h-full w-auto object-contain"
          />
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    if connected?(socket) do
      ImaginativeRestorationWeb.Endpoint.subscribe("sketch:updated")
      Process.send_after(self(), :pre_populate_sketches, 1000)
    end

    {:ok, assign(socket, sketch: nil, capture: Map.has_key?(params, "capture") or Map.has_key?(params, "capture_box")),
     layout: {ImaginativeRestorationWeb.Layouts, :canvas}}
  end

  @impl true
  def handle_event("webcam_frame", %{"frame" => dataurl}, socket) do
    # only run the AI pipeline if stuff has changed recently
    latest_raw_image = Utils.to_image!(dataurl)

    if Utils.changed_recently?(latest_raw_image) do
      Task.start(fn ->
        dataurl
        |> ImaginativeRestoration.Sketches.init!()
        |> ImaginativeRestoration.Sketches.crop_and_label!()
        |> ImaginativeRestoration.Sketches.process!()
      end)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(%Broadcast{topic: "sketch:updated", event: "process"} = message, socket) do
    sketch = message.payload.data
    thumbnail_dataurl = Utils.thumbnail!(sketch.processed)

    {:noreply,
     socket
     |> assign(sketch: sketch)
     |> push_event("add_sketches", %{sketches: [%{id: sketch.id, dataurl: thumbnail_dataurl}]})}
  end

  @impl true
  def handle_info(%Broadcast{topic: "sketch:updated"} = message, socket) do
    sketch = message.payload.data
    {:noreply, assign(socket, sketch: sketch)}
  end

  @impl true
  def handle_info(:pre_populate_sketches, socket) do
    sketches =
      Enum.map(Utils.recent_sketches(3), fn %Sketch{id: id, processed: processed} -> %{id: id, dataurl: processed} end)

    {:noreply, push_event(socket, "add_sketches", %{sketches: sketches})}
  end

  defp pipeline_phase(%Sketch{label: nil}), do: :labelling
  defp pipeline_phase(%Sketch{processed: nil}), do: :processing
  defp pipeline_phase(%Sketch{}), do: :completed
  defp pipeline_phase(nil), do: :waiting
end
