defmodule ImaginativeRestorationWeb.AdminLive do
  @moduledoc """
  Consolidated admin interface combining prompt management and configuration.
  """
  use ImaginativeRestorationWeb, :live_view

  import ImaginativeRestorationWeb.AppComponents

  alias ImaginativeRestoration.Sketches.Prompt
  alias ImaginativeRestoration.Sketches.Sketch
  alias ImaginativeRestoration.Utils

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 space-y-6 text-white">
      <!-- Header -->
      <h1 class="text-2xl font-bold">Admin Dashboard</h1>
      
      <!-- Live Webcam with Crop Box and Frame Differences -->
      <div class="bg-gray-800 p-4 rounded-lg">
        <h2 class="text-lg font-semibold mb-4">Live Webcam Configuration</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <h3 class="text-sm font-medium mb-2">Live Stream with Crop Box</h3>
            <div class="relative h-[300px] bg-black">
              <.webcam_capture class="h-full" capture_interval={1_000} show_full_frame={true} camera_error={@camera_error} />
              <img class="absolute inset-0 h-full object-contain" src={@frame} />
              <!-- Crop box overlay will be drawn by JavaScript -->
              <div id="crop-box-overlay" class="absolute inset-0 pointer-events-none"></div>
            </div>
          </div>
          
          <div>
            <h3 class="text-sm font-medium mb-2">Frame Difference Calibration</h3>
            <div class="bg-gray-900 p-3 rounded">
              <p class="text-sm mb-2">Current threshold: <span class="font-mono text-yellow-400">{@image_difference_threshold}</span></p>
              <p class="text-sm mb-2">Inter-frame distances:</p>
              <div class="font-mono text-lg">
                <%= for distance <- Utils.inter_image_distances(@recent_images) do %>
                  <span style={"color: #{if distance > @image_difference_threshold, do: "#ef4444", else: "#10b981"}"}>
                    {distance}
                  </span>
                <% end %>
              </div>
              <p class="text-xs text-gray-400 mt-2">
                Red values exceed threshold and trigger capture. Green values are skipped.
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- System Information -->
      <div class="bg-gray-800 p-4 rounded-lg">
        <h2 class="text-lg font-semibold mb-4">System Information</h2>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="bg-gray-900 p-3 rounded">
            <h3 class="text-sm font-medium text-gray-400">Disk Space</h3>
            <p class="text-2xl font-mono">{@disk_free_gb} GB free</p>
            <p class="text-sm text-gray-400">{@disk_used_gb} GB used of {@disk_total_gb} GB</p>
            <div class="w-full bg-gray-700 rounded-full h-2 mt-2">
              <div class="bg-blue-500 h-2 rounded-full" style={"width: #{@disk_used_percent}%"}></div>
            </div>
          </div>
          
          <div class="bg-gray-900 p-3 rounded">
            <h3 class="text-sm font-medium text-gray-400">Capture Interval</h3>
            <p class="text-2xl font-mono">{@capture_interval_seconds}s</p>
          </div>
          
          <div class="bg-gray-900 p-3 rounded">
            <h3 class="text-sm font-medium text-gray-400">Total Sketches</h3>
            <p class="text-2xl font-mono">{@total_sketches}</p>
          </div>
        </div>
      </div>

      <!-- Recent Sketches -->
      <div class="bg-gray-800 p-4 rounded-lg">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-lg font-semibold">Recent Sketch Pipeline Results</h2>
          <.button phx-click="process_recent" class="bg-blue-600 hover:bg-blue-700">
            Process Recent Sketches
          </.button>
        </div>
        
        <div id="sketches" phx-update="stream" class="space-y-4">
          <div :for={{dom_id, sketch} <- @streams.sketches} id={dom_id} 
               class="bg-gray-900 p-3 rounded-lg">
            <div class="flex gap-4 items-center">
              <div class="flex-1">
                <p class="text-sm text-gray-400 mb-1">
                  {Calendar.strftime(sketch.inserted_at, "%Y-%m-%d %H:%M:%S")}
                </p>
                <div class="flex gap-4 h-[120px]">
                  <div>
                    <p class="text-xs text-gray-400 mb-1">Input</p>
                    <img src={sketch.raw} class="h-full rounded" />
                  </div>
                  <div>
                    <p class="text-xs text-gray-400 mb-1">Output</p>
                    <img src={sketch.processed || sketch.raw} 
                         class={["h-full rounded", !sketch.processed && "opacity-50"]} />
                    <span :if={!sketch.processed} class="text-xs text-yellow-400">Processing...</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Prompt Examples -->
      <div class="bg-gray-800 p-4 rounded-lg">
        <h2 class="text-lg font-semibold mb-4">Example Prompts</h2>
        <ul class="list-disc list-inside space-y-1">
          <li :for={prompt <- @sample_prompts} class="text-sm">{prompt}</li>
        </ul>
        <p class="text-sm text-gray-400 mt-2">
          Prompts are dynamically generated by combining random adjectives, sea creatures, and art styles.
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      ImaginativeRestorationWeb.Endpoint.subscribe("sketch:updated")
      # Update disk space every 30 seconds
      :timer.send_interval(30_000, self(), :update_disk_space)
    end

    # Generate sample prompts
    sample_prompts = Enum.map(1..4, fn _ -> Prompt.random_prompt() end)

    # Get recent sketches
    sketches =
      Sketch
      |> Ash.Query.for_read(:read)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(5)
      |> Ash.read!()

    # Get total sketch count
    total_sketches = Sketch |> Ash.count!()

    # Get configuration values
    difference_threshold = Application.get_env(:imaginative_restoration, :image_difference_threshold)
    capture_interval = Application.get_env(:imaginative_restoration, :webcam_capture_interval)
    
    # Get disk space info
    {disk_free_gb, disk_used_gb, disk_total_gb, disk_used_percent} = get_disk_space_info()

    {:ok,
     socket
     |> stream(:sketches, sketches)
     |> assign(
       sample_prompts: sample_prompts,
       frame: nil,
       recent_images: [],
       image_difference_threshold: difference_threshold,
       capture_interval_seconds: div(capture_interval, 1000),
       total_sketches: total_sketches,
       disk_free_gb: disk_free_gb,
       disk_used_gb: disk_used_gb,
       disk_total_gb: disk_total_gb,
       disk_used_percent: disk_used_percent,
       camera_error: nil
     )}
  end

  @impl true
  def handle_event("webcam_frame", %{"frame" => dataurl}, socket) do
    number_of_images = 10
    latest_raw_image = Utils.to_image!(dataurl)

    recent_images =
      Enum.take([latest_raw_image | socket.assigns.recent_images], number_of_images)

    {:noreply, assign(socket, frame: dataurl, recent_images: recent_images)}
  end

  @impl true
  def handle_event("camera_status", %{"status" => "ready"}, socket) do
    # Camera is working, clear any error
    {:noreply, assign(socket, camera_error: nil)}
  end

  def handle_event("camera_status", %{"status" => "error"} = params, socket) do
    # Camera has an error, display it
    camera_error = %{
      type: params["error_type"],
      message: params["error_message"]
    }
    
    Logger.warning("Camera error: #{camera_error.type} - #{camera_error.message}")
    
    {:noreply, assign(socket, camera_error: camera_error)}
  end

  @impl true
  def handle_event("process_recent", _params, socket) do
    sketches =
      Sketch
      |> Ash.Query.for_read(:read)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(5)
      |> Ash.read!()

    sketches
    |> Task.async_stream(
      fn sketch ->
        # doesn't actually matter if this errors or not
        ImaginativeRestoration.Sketches.process(sketch)
      end,
      timeout: :infinity
    )
    |> Stream.run()

    {:noreply, put_flash(socket, :info, "Processing recent sketches...")}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "sketch:updated"} = message, socket) do
    sketch = message.payload.data
    {:noreply, stream_insert(socket, :sketches, sketch, at: 0, limit: 5)}
  end

  @impl true
  def handle_info(:update_disk_space, socket) do
    {disk_free_gb, disk_used_gb, disk_total_gb, disk_used_percent} = get_disk_space_info()
    
    {:noreply,
     assign(socket,
       disk_free_gb: disk_free_gb,
       disk_used_gb: disk_used_gb,
       disk_total_gb: disk_total_gb,
       disk_used_percent: disk_used_percent
     )}
  end

  defp get_disk_space_info do
    # Use df command to get disk space info for the root partition
    case System.cmd("df", ["-h", "/"]) do
      {output, 0} ->
        # Parse the df output
        lines = String.split(output, "\n")
        # Get the data line (second line)
        case Enum.at(lines, 1) do
          nil ->
            {0, 0, 0, 0}
          
          line ->
            # Split by whitespace and get relevant fields
            parts = String.split(line, ~r/\s+/)
            # Format: Filesystem Size Used Avail Use% Mounted
            case parts do
              [_filesystem, size, used, avail, use_percent | _rest] ->
                # Convert sizes from human-readable format
                total_gb = parse_size_to_gb(size)
                used_gb = parse_size_to_gb(used)
                free_gb = parse_size_to_gb(avail)
                percent = String.trim_trailing(use_percent, "%") |> String.to_integer()
                
                {free_gb, used_gb, total_gb, percent}
              
              _ ->
                {0, 0, 0, 0}
            end
        end
      
      _ ->
        {0, 0, 0, 0}
    end
  end

  defp parse_size_to_gb(size_str) do
    # Parse sizes like "50G", "512M", "1.2T" to GB
    case Regex.run(~r/^([\d.]+)([KMGT]?)/, size_str) do
      [_, number, unit] ->
        num = String.to_float(number)
        case unit do
          "T" -> round(num * 1024)
          "G" -> round(num)
          "M" -> round(num / 1024)
          "K" -> round(num / 1024 / 1024)
          _ -> round(num)
        end
      
      _ ->
        0
    end
  rescue
    _ -> 0
  end
end