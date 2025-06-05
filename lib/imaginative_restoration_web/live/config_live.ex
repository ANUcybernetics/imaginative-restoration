defmodule ImaginativeRestorationWeb.ConfigLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

  import ImaginativeRestorationWeb.AppComponents

  alias ImaginativeRestoration.Utils

  require Logger

  def distances(assigns) do
    ~H"""
    <div class="mt-4 text-4xl font-mono">
      <%= for distance <- Utils.inter_image_distances(@recent_images) do %>
        <span style={"color: #{if distance > @threshold, do: "red", else: "white"}"}>
          {distance}
        </span>
      <% end %>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class="relative flex items-center justify-center size-full h-[300px]">
        <.webcam_capture class="h-full" capture_interval={1_000} />
        <img class="max-h-full" src={@frame} />
      </div>
      <.distances recent_images={@recent_images} threshold={@image_difference_threshold} />
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    difference_threshold = Application.get_env(:imaginative_restoration, :image_difference_threshold)

    {:ok,
     assign(socket,
       frame: nil,
       image_distances: [],
       image_difference_threshold: difference_threshold,
       recent_images: []
     ), layout: {ImaginativeRestorationWeb.Layouts, :canvas}}
  end

  @impl true
  def handle_event("webcam_frame", %{"frame" => dataurl}, socket) do
    number_of_images = 10
    latest_raw_image = Utils.to_image!(dataurl)

    recent_images =
      Enum.take([latest_raw_image | socket.assigns.recent_images], number_of_images)

    dbg()

    {:noreply, assign(socket, frame: dataurl, recent_images: recent_images)}
  end
end
