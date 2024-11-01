defmodule ImaginativeRestorationWeb.AppComponents do
  @moduledoc false

  use Phoenix.Component

  attr :class, :string, default: nil
  attr :capture_interval, :integer, default: 60_000

  def webcam_capture(assigns) do
    ~H"""
    <div class={["relative", @class]}>
      <video
        id="video"
        phx-hook="WebcamStream"
        data-capture-interval={@capture_interval}
        class="h-full w-auto"
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
          stroke="#08f"
          transform-origin="center"
        />
        <rect id="flash-overlay" x="0" y="0" width="100%" height="100%" fill="#ffffff" opacity="0" />
      </svg>
    </div>
    """
  end
end
