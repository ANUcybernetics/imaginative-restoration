defmodule ImaginativeRestorationWeb.IndexLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

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
        <video
          id="video"
          phx-hook="WebcamStream"
          class="absolute top-8 right-8 size-[240px] object-cover"
        >
          Video stream not available.
        </video>
        <img src={@sketch_dataurl} class="absolute bottom-8 right-8 size-[240px] object-cover" />
        <img src={@processed_dataurl} class="absolute bottom-8 left-8 size-[240px] object-cover" />
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, sketch_dataurl: nil, processed_dataurl: nil)}
  end

  def handle_event("webcam_frame", %{"frame" => frame_data}, socket) do
    Task.async(fn -> ImaginativeRestoration.AI.process(frame_data) end)
    {:noreply, assign(socket, sketch_dataurl: frame_data)}
  end

  def handle_info({ref, {:ok, processed_dataurl}}, socket) do
    # Cancel the monitoring since the task completed successfully
    Process.demonitor(ref, [:flush])
    {:noreply, assign(socket, processed_dataurl: processed_dataurl)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, socket) do
    # Handle task failure
    IO.puts("Processing failed: #{inspect(reason)}")
    {:noreply, socket}
  end
end
