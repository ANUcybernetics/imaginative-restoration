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
    <audio :if={!@capture?} id="background-audio" autoplay loop>
      <source
        src="https://fly.storage.tigris.dev/imaginative-restoration-sketches/592086__soundflakes__soundflakes-horizon-of-the-unknown.mp3"
        type="audio/mp3"
      />
    </audio>
    <div class="relative flex items-center justify-center size-full">
      <div class="w-full max-w-[calc(100vh*4/3)] aspect-[4/3]">
        <div class="relative w-full h-full">
          <canvas id="sketch-canvas" phx-hook="SketchCanvas" class="w-full h-full object-contain">
          </canvas>
        </div>
        <div :if={@capture?} class="absolute top-8 left-8 flex gap-8 h-[200px] backdrop-blur-md">
          <.webcam_capture capture_interval={
            Application.get_env(:imaginative_restoration, :webcam_capture_interval)
          } />
          <div :if={@sketch} class="relative">
            <img
              src={@sketch.raw}
              class={[
                "h-full w-auto object-contain",
                pipeline_phase(@sketch) != :completed && "sketch-processing",
                @skip_process? && "grayscale"
              ]}
            />
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
      # Process.send_after(self(), :spam_new_sketch, 1000)
    end

    capture? = Map.has_key?(params, "capture") or Map.has_key?(params, "capture_box")
    difference_threshold = Application.get_env(:imaginative_restoration, :image_difference_threshold)

    {:ok,
     assign(socket,
       # the most recent sketch (including ones that are still processing)
       sketch: nil,
       # boolean: whether to capture webcam frames (set via URL params)
       capture?: capture?,
       # the most recent webcam frame (whether or not it was processed)
       frame_image: nil,
       # are we skipping (not processing) the last frame because it didn't change?
       skip_process?: true,
       page_title: (capture? && "Capture") || "Display",
       image_difference_threshold: difference_threshold
     ), layout: {ImaginativeRestorationWeb.Layouts, :canvas}}
  end

  @impl true
  def handle_event("webcam_frame", %{"frame" => dataurl}, socket) do
    frame_image = Utils.to_image!(dataurl)

    skip_process? =
      case socket.assigns.frame_image do
        nil ->
          false

        previous_frame_image ->
          frame_difference(previous_frame_image, frame_image) <= socket.assigns.image_difference_threshold
      end

    if skip_process? do
      Logger.info("No significant changes detected in webcam frame, skipping processing")
    else
      start_processing_task(dataurl)
    end

    {:noreply,
     assign(
       socket,
       previous_image: frame_image,
       skip_process?: skip_process?,
       frame_image: frame_image
     )}
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

  @impl true
  def handle_info(:spam_new_sketch, socket) do
    [%Sketch{id: id, processed: processed}] = Utils.recent_sketches(1)
    Process.send_after(self(), :spam_new_sketch, 1000)
    {:noreply, push_event(socket, "add_sketches", %{sketches: [%{id: id, dataurl: processed}]})}
  end

  defp pipeline_phase(%Sketch{processed: nil}), do: :processing
  defp pipeline_phase(%Sketch{}), do: :completed
  defp pipeline_phase(nil), do: :waiting

  defp start_processing_task(dataurl) do
    Task.start(fn ->
      dataurl
      |> ImaginativeRestoration.Sketches.init!()
      |> ImaginativeRestoration.Sketches.process!()
    end)
  end

  defp frame_difference(frame1, frame2) do
    {:ok, distance} = Image.hamming_distance(frame1, frame2)
    distance
  end
end
