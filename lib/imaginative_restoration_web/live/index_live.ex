defmodule ImaginativeRestorationWeb.IndexLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="absolute top-8 right-8">
      <video id="video" phx-hook="WebcamStream" class="size-[240px] object-cover">
        Video stream not available.
      </video>
    </div>
    """
  end
end
