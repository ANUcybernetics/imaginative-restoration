defmodule ImaginativeRestorationWeb.AppLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

  import ImaginativeRestorationWeb.AppComponents

  alias ImaginativeRestoration.Sketches
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
            <.webcam_capture
              capture_interval={
                Application.get_env(:imaginative_restoration, :webcam_capture_interval)
              }
              camera_error={@camera_error}
            />
          </div>
          
    <!-- Recent processed images -->
          <div :for={image <- @recent_images} class="relative h-full aspect-[4/3]">
            <img
              src={Sketch.display_url(image)}
              class={[
                "w-full h-full object-contain",
                !processed?(image) && "sketch-processing"
              ]}
            />
            <span
              :if={!processed?(image)}
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
    end

    capture? = Map.has_key?(params, "capture") or Map.has_key?(params, "capture_box")
    difference_threshold = Application.get_env(:imaginative_restoration, :image_difference_threshold)

    {:ok,
     assign(socket,
       # boolean: whether to capture webcam frames (set via URL params)
       capture?: capture?,
       # the most recent webcam frame (for comparison with next frame)
       frame_image: nil,
       # list of the 5 most recent sketches
       recent_images: [],
       page_title: (capture? && "Capture") || "Display",
       image_difference_threshold: difference_threshold,
       # camera error state
       camera_error: nil,
       # sketch id of the currently in-flight submission (or :pending while submitting)
       current_sketch_id: nil
     ), layout: {ImaginativeRestorationWeb.Layouts, :canvas}}
  end

  @impl true
  def handle_event("webcam_frame", %{"frame" => "data:image/" <> _ = dataurl} = params, socket) do
    if Map.get(params, "is_admin", false) do
      {:noreply, socket}
    else
      handle_capture_frame(dataurl, socket)
    end
  end

  @impl true
  def handle_event("camera_status", %{"status" => "ready"}, socket) do
    {:noreply, assign(socket, camera_error: nil)}
  end

  def handle_event("camera_status", %{"status" => "error"} = params, socket) do
    camera_error = %{type: params["error_type"], message: params["error_message"]}
    Logger.warning("Camera error: #{camera_error.type} - #{camera_error.message}")
    {:noreply, assign(socket, camera_error: camera_error)}
  end

  @impl true
  def handle_async(:submit, {:ok, %Sketch{id: id}}, socket) do
    {:noreply, assign(socket, current_sketch_id: id)}
  end

  def handle_async(:submit, {:exit, reason}, socket) do
    Logger.error("Sketch submission failed: #{inspect(reason)}")
    {:noreply, assign(socket, current_sketch_id: nil)}
  end

  @impl true
  def handle_info(%Broadcast{topic: "sketch:updated"} = message, socket) do
    sketch = message.payload.data

    socket
    |> update(:recent_images, &update_recent_images(&1, sketch))
    |> clear_current_if_done(sketch)
    |> maybe_push_thumbnail(sketch)
    |> noreply()
  end

  def handle_info(:pre_populate_sketches, socket) do
    recent_sketches = Utils.recent_sketches(5)
    sketches = Enum.map(recent_sketches, fn sketch -> %{id: sketch.id, dataurl: Sketch.display_url(sketch)} end)

    {:noreply,
     socket
     |> assign(recent_images: recent_sketches)
     |> push_event("add_sketches", %{sketches: sketches})}
  end

  defp handle_capture_frame(dataurl, socket) do
    if socket.assigns.current_sketch_id do
      {:noreply, socket}
    else
      frame_image = Utils.to_image!(dataurl)

      skip? =
        case socket.assigns.frame_image do
          nil ->
            false

          last_frame ->
            frame_difference(last_frame, frame_image) <= socket.assigns.image_difference_threshold
        end

      if skip? do
        Logger.debug("Frame hasn't changed enough (below threshold), skipping processing")
        {:noreply, assign(socket, frame_image: frame_image)}
      else
        raw_data = Utils.decode_dataurl!(dataurl)

        socket =
          socket
          |> assign(frame_image: frame_image, current_sketch_id: :pending)
          |> start_async(:submit, fn ->
            raw_data
            |> Sketches.init!()
            |> Sketches.submit_generation!()
          end)
          |> push_event("capture_triggered", %{})

        {:noreply, socket}
      end
    end
  end

  defp frame_difference(frame1, frame2) do
    case Image.compare(frame1, frame2, metric: :rmse) do
      {:ok, difference, _diff_image} ->
        difference * 100

      {:error, _reason} ->
        {:ok, distance} = Image.hamming_distance(frame1, frame2)
        distance
    end
  end

  defp clear_current_if_done(socket, %Sketch{state: state} = sketch) when state in [:succeeded, :failed] do
    if socket.assigns.current_sketch_id == sketch.id do
      assign(socket, current_sketch_id: nil)
    else
      socket
    end
  end

  defp clear_current_if_done(socket, _sketch), do: socket

  defp maybe_push_thumbnail(socket, %Sketch{state: :succeeded} = sketch) do
    case Sketch.display_url(sketch) do
      nil -> socket
      dataurl -> push_event(socket, "add_sketches", %{sketches: [%{id: sketch.id, dataurl: dataurl}]})
    end
  end

  defp maybe_push_thumbnail(socket, _sketch), do: socket

  defp processed?(%Sketch{thumbnail: t}) when is_binary(t), do: true
  defp processed?(%Sketch{processed_data: p}) when is_binary(p), do: true
  defp processed?(_), do: false

  defp update_recent_images(recent_images, new_sketch) do
    case Enum.find_index(recent_images, &(&1.id == new_sketch.id)) do
      nil -> Enum.take([new_sketch | recent_images], 5)
      index -> List.replace_at(recent_images, index, new_sketch)
    end
  end

  defp noreply(socket), do: {:noreply, socket}
end
