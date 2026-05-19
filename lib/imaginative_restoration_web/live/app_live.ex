defmodule ImaginativeRestorationWeb.AppLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

  import ImaginativeRestorationWeb.AppComponents

  alias ImaginativeRestoration.CameraWatchdog
  alias ImaginativeRestoration.OperatingHours
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
      # Force a fullsweep GC every few minor GCs so refc binaries and Vix NIF
      # resources from per-frame image processing don't accumulate in C-heap.
      # Without this the LV's Erlang heap stays small (the Vix.Vips.Image
      # references are tiny) so GC rarely runs, and libvips memory leaks until
      # the OS OOM-kills the BEAM.
      Process.flag(:fullsweep_after, 5)
      ImaginativeRestorationWeb.Endpoint.subscribe("sketch:updated")
      Process.send_after(self(), :pre_populate_sketches, 1000)
    end

    capture? = Map.has_key?(params, "capture") or Map.has_key?(params, "capture_box")
    change_threshold = Application.get_env(:imaginative_restoration, :image_difference_threshold)
    motion_threshold = Application.get_env(:imaginative_restoration, :frame_settle_threshold)
    stability_window = Application.get_env(:imaginative_restoration, :stability_window_ticks)
    lock_timeout_ms = Application.get_env(:imaginative_restoration, :lock_timeout_ms)

    {:ok,
     assign(socket,
       # boolean: whether to capture webcam frames (set via URL params)
       capture?: capture?,
       # reference frame to compare against — the last frame that triggered
       # processing (or the first frame seen, while bootstrapping)
       baseline_image: nil,
       # previous tick's frame, used to compute per-tick frame-to-frame diff
       previous_image: nil,
       # rolling window of the last N frame-to-frame diffs (most recent first)
       settle_history: [],
       # latch: set true on any per-tick diff above motion_threshold, cleared
       # on trigger (or on a settled-but-no-change outcome). The trigger
       # precondition; without it, slow lighting drift would qualify.
       motion_observed?: false,
       # list of the 5 most recent sketches
       recent_images: [],
       page_title: (capture? && "Capture") || "Display",
       change_threshold: change_threshold,
       motion_threshold: motion_threshold,
       stability_window: stability_window,
       # camera error state
       camera_error: nil,
       # sketch id of the currently in-flight submission (or :pending while submitting)
       current_sketch_id: nil,
       # safety net: cleared when the sketch broadcast arrives, fires if not
       stuck_lock_timer: nil,
       lock_generation: 0,
       lock_timeout_ms: lock_timeout_ms
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

    socket
    |> assign(current_sketch_id: nil)
    |> cancel_stuck_lock_timer()
    |> noreply()
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

  def handle_info({:stuck_lock_timeout, generation}, socket) do
    if socket.assigns.lock_generation == generation and socket.assigns.current_sketch_id do
      Logger.warning(
        "LiveView submission lock stuck (#{inspect(socket.assigns.current_sketch_id)}); clearing as safety net"
      )

      {:noreply, assign(socket, current_sketch_id: nil, stuck_lock_timer: nil)}
    else
      {:noreply, socket}
    end
  end

  defp handle_capture_frame(dataurl, socket) do
    cond do
      socket.assigns.current_sketch_id ->
        {:noreply, socket}

      not OperatingHours.open?() ->
        # Outside hours: adopt the latest frame as baseline/previous and wipe
        # the motion state, so the first frame after opening doesn't trip on
        # overnight lighting drift or stale latched motion.
        frame_image = Utils.to_image!(dataurl)

        {:noreply,
         assign(socket,
           baseline_image: frame_image,
           previous_image: frame_image,
           settle_history: [],
           motion_observed?: false
         )}

      true ->
        CameraWatchdog.heartbeat()
        frame_image = Utils.to_image!(dataurl)

        case classify_frame(frame_image, socket.assigns) do
          {:bootstrap, state} ->
            {:noreply, assign(socket, Map.put(state, :baseline_image, frame_image))}

          {:trigger, state} ->
            Logger.info("Triggering capture change=#{Float.round(state.change, 3)}")
            trigger_capture(frame_image, dataurl, socket)

          {reason, state} ->
            Logger.debug(
              "Frame skipped (#{reason}) settle=#{Float.round(state.settle, 3)} motion_observed?=#{state.motion_observed?}"
            )

            {:noreply, assign(socket, state)}
        end
    end
  end

  # The classifier returns `{outcome, state}` where `state` is the partial
  # socket assigns to apply (always includes :previous_image, :settle_history,
  # :motion_observed?). Outcomes:
  #
  #   :bootstrap     — first frame this session; caller also sets baseline
  #   :in_motion     — per-tick diff above motion_threshold
  #   :warming_up    — not enough history yet to call the scene settled
  #   :still_settling — recent ticks still contain motion
  #   :no_motion     — scene quiet but no motion since last trigger (drift)
  #   :no_change     — scene quiet, motion was observed, but change vs
  #                    baseline is below the threshold (latch is cleared)
  #   :trigger       — scene quiet AND motion was observed AND change is
  #                    above threshold; `state` carries the :change value
  defp classify_frame(frame_image, %{baseline_image: nil} = assigns) do
    {:bootstrap,
     %{
       previous_image: frame_image,
       settle_history: [],
       motion_observed?: assigns.motion_observed?
     }}
  end

  defp classify_frame(frame_image, %{
         baseline_image: baseline,
         previous_image: previous,
         settle_history: history,
         motion_observed?: motion_observed?,
         change_threshold: change_threshold,
         motion_threshold: motion_threshold,
         stability_window: window
       }) do
    settle = frame_difference(previous, frame_image)
    history = [settle | Enum.take(history, window - 1)]
    in_motion? = settle > motion_threshold

    base_state = %{
      previous_image: frame_image,
      settle_history: history,
      motion_observed?: motion_observed? or in_motion?,
      settle: settle
    }

    cond do
      in_motion? ->
        {:in_motion, base_state}

      length(history) < window ->
        {:warming_up, base_state}

      Enum.any?(history, &(&1 > motion_threshold)) ->
        {:still_settling, base_state}

      not base_state.motion_observed? ->
        {:no_motion, base_state}

      true ->
        change = frame_difference(baseline, frame_image)

        if change > change_threshold do
          {:trigger, Map.put(base_state, :change, change)}
        else
          # Quiet scene that does not meaningfully differ from baseline. Clear
          # the latch so the next person-driven disturbance starts a fresh
          # motion → rest cycle rather than counting against this one.
          {:no_change, %{base_state | motion_observed?: false}}
        end
    end
  end

  defp trigger_capture(frame_image, dataurl, socket) do
    raw_data = Utils.decode_dataurl!(dataurl)

    socket
    # The current frame becomes the new baseline immediately — so a failed
    # submission won't retrigger on the same scene, and the artist has to
    # change something for the next capture.
    |> assign(
      baseline_image: frame_image,
      previous_image: frame_image,
      settle_history: [],
      motion_observed?: false,
      current_sketch_id: :pending
    )
    |> arm_stuck_lock_timer()
    |> start_async(:submit, fn ->
      raw_data
      |> Sketches.init!()
      |> Sketches.submit_generation!()
    end)
    |> push_event("capture_triggered", %{})
    |> noreply()
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

  defp arm_stuck_lock_timer(socket) do
    socket = cancel_stuck_lock_timer(socket)
    generation = socket.assigns.lock_generation + 1
    timeout = socket.assigns.lock_timeout_ms
    timer = Process.send_after(self(), {:stuck_lock_timeout, generation}, timeout)

    assign(socket, stuck_lock_timer: timer, lock_generation: generation)
  end

  defp cancel_stuck_lock_timer(socket) do
    case socket.assigns.stuck_lock_timer do
      nil ->
        socket

      ref ->
        Process.cancel_timer(ref)
        assign(socket, stuck_lock_timer: nil)
    end
  end

  defp clear_current_if_done(socket, %Sketch{state: state} = sketch) when state in [:succeeded, :failed] do
    if socket.assigns.current_sketch_id == sketch.id do
      socket
      |> assign(current_sketch_id: nil)
      |> cancel_stuck_lock_timer()
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
