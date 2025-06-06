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
        <div :if={@capture?} class="absolute top-[100px] left-[350px] flex gap-8 h-[120px]">
          <!-- Live webcam feed -->
          <div class="relative h-full aspect-[4/3]">
            <.webcam_capture capture_interval={
              Application.get_env(:imaginative_restoration, :webcam_capture_interval)
            } />
          </div>
          
    <!-- Recent processed images -->
          <div :for={image <- @recent_images} class="relative h-full aspect-[4/3]">
            <img
              src={image.processed || image.raw}
              class={[
                "w-full h-full object-contain",
                !image.processed && "sketch-processing"
              ]}
            />
            <span
              :if={!image.processed}
              class="absolute left-1/2 bottom-2 -translate-x-1/2 text-sm font-lacquer font-semibold px-1 py-0.5 text-[#8B2E15] backdrop-blur-md rounded-sm"
            >
              Processing...
            </span>
          </div>
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
       # boolean: whether to capture webcam frames (set via URL params)
       capture?: capture?,
       # the most recent webcam frame (whether or not it was processed)
       frame_image: nil,
       # list of the 5 most recent processed images
       recent_images: [],
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
      case get_oldest_processed_image(socket.assigns.recent_images) do
        nil ->
          false

        oldest_image ->
          frame_difference(oldest_image, frame_image) <= socket.assigns.image_difference_threshold
      end

    if skip_process? do
      Logger.info("No significant changes detected in webcam frame, skipping processing")
    else
      start_processing_task(dataurl)
    end

    {:noreply,
     assign(
       socket,
       skip_process?: skip_process?,
       frame_image: frame_image
     )}
  end

  @impl true
  def handle_info(%Broadcast{topic: "sketch:updated", event: "process"} = message, socket) do
    sketch = message.payload.data
    updated_recent_images = update_recent_images(socket.assigns.recent_images, sketch)

    pid = self()

    Task.Supervisor.start_child(ImaginativeRestoration.TaskSupervisor, fn ->
      thumbnail_dataurl = Utils.thumbnail!(sketch.processed)
      send(pid, {:thumbnail_ready, sketch, thumbnail_dataurl})
    end)

    {:noreply, assign(socket, recent_images: updated_recent_images)}
  end

  @impl true
  def handle_info({:thumbnail_ready, sketch, thumbnail_dataurl}, socket) do
    {:noreply, push_event(socket, "add_sketches", %{sketches: [%{id: sketch.id, dataurl: thumbnail_dataurl}]})}
  end

  @impl true
  def handle_info(%Broadcast{topic: "sketch:updated"} = message, socket) do
    sketch = message.payload.data
    updated_recent_images = update_recent_images(socket.assigns.recent_images, sketch)
    {:noreply, assign(socket, recent_images: updated_recent_images)}
  end

  @impl true
  def handle_info(:pre_populate_sketches, socket) do
    recent_sketches = Utils.recent_sketches(5)

    # Convert to thumbnails for canvas display
    sketches =
      Enum.map(recent_sketches, fn %Sketch{id: id, processed: processed} -> %{id: id, dataurl: processed} end)

    {:noreply,
     socket
     |> assign(recent_images: recent_sketches)
     |> push_event("add_sketches", %{sketches: sketches})}
  end

  @impl true
  def handle_info(:spam_new_sketch, socket) do
    [%Sketch{id: id, processed: processed}] = Utils.recent_sketches(1)
    Process.send_after(self(), :spam_new_sketch, 1000)
    {:noreply, push_event(socket, "add_sketches", %{sketches: [%{id: id, dataurl: processed}]})}
  end

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

  defp get_oldest_processed_image([]), do: nil

  defp get_oldest_processed_image(recent_images) do
    recent_images
    |> Enum.reverse()
    |> Enum.find(& &1.processed)
    |> case do
      nil -> nil
      sketch -> Utils.to_image!(sketch.processed)
    end
  end

  defp update_recent_images(recent_images, new_sketch) do
    # Find if this sketch already exists in the list
    case Enum.find_index(recent_images, &(&1.id == new_sketch.id)) do
      nil ->
        # New sketch, add to front and keep only 5 most recent
        Enum.take([new_sketch | recent_images], 5)

      index ->
        # Update existing sketch
        List.replace_at(recent_images, index, new_sketch)
    end
  end
end
