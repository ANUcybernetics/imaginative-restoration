defmodule ImaginativeRestorationWeb.IndexLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="w-full">
      <video autoplay loop muted class="w-full h-full object-cover">
        <source
          src="https://fly.storage.tigris.dev/imaginative-restoration-sketches/IMGRES_FirstRoughEdit_V1.0_DH_11.09.24.mp4"
          type="video/mp4"
        /> Your browser does not support the video tag.
      </video>
    </div>
    <div class="absolute top-8 right-8">
      <video id="video" phx-hook="WebcamStream" class="size-[240px] object-cover">
        Video stream not available.
      </video>
    </div>
    """
  end
end
