defmodule ImaginativeRestorationWeb.AppComponents do
  @moduledoc false

  use Phoenix.Component

  attr :class, :string, default: nil
  attr :capture_interval, :integer, default: 60_000
  attr :show_full_frame, :boolean, default: false
  attr :camera_error, :map, default: nil

  def webcam_capture(assigns) do
    ~H"""
    <div class={["relative w-full h-full", @class]}>
      <video
        id="video"
        phx-hook="WebcamStream"
        data-capture-interval={@capture_interval}
        data-show-full-frame={@show_full_frame}
        class={["w-full h-full object-contain", @camera_error && "hidden"]}
      >
        Webcam video stream not available.
      </video>
      
      <div :if={@camera_error} class="absolute inset-0 flex items-center justify-center bg-gray-900">
        <div class="text-center p-6">
          <div class="mb-4">
            <svg class="w-16 h-16 mx-auto text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                    d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9">
              </path>
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-white mb-2">Camera Not Available</h3>
          <p class="text-gray-300 text-sm"><%= @camera_error.message %></p>
        </div>
      </div>
      
      <svg class="absolute inset-0 w-full h-full pointer-events-none">
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
