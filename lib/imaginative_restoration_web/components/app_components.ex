defmodule ImaginativeRestorationWeb.AppComponents do
  @moduledoc false

  use Phoenix.Component

  attr :class, :string, default: nil
  attr :capture_interval, :integer, default: 60_000

  def webcam_capture(assigns) do
    ~H"""
    <div class={["relative w-full h-full", @class]}>
      <video
        id="video"
        phx-hook="WebcamStream"
        data-capture-interval={@capture_interval}
        class="w-full h-full object-contain"
      >
        Webcam video stream not available.
      </video>
      <svg class="absolute inset-0 w-full h-full pointer-events-none">
        <line
          id="progress-line"
          x1="0"
          y1="10"
          x2="100%"
          y2="10"
          stroke-width="20"
          stroke="#a07003"
          transform-origin="center"
        />
        <rect id="flash-overlay" x="0" y="0" width="100%" height="100%" fill="#ffffff" opacity="0" />
      </svg>
    </div>
    """
  end

  def sketch(assigns) do
    ~H"""
    <div id={@id} class="flex h-[150px] justify-between">
      <img src={@sketch.raw} class="h-full" />
      <img src={@sketch.processed} class="h-full" />
    </div>
    """
  end
end
