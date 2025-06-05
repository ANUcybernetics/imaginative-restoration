defmodule ImaginativeRestorationWeb.PromptLive do
  @moduledoc """
  LiveView for managing sketch processing and viewing recent sketches.
  """
  use ImaginativeRestorationWeb, :live_view

  import ImaginativeRestorationWeb.AppComponents

  alias ImaginativeRestoration.Sketches.Prompt
  alias ImaginativeRestoration.Sketches.Sketch

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h2 class="text-lg font-semibold mb-4">Available Prompts</h2>
        <ul class="list-disc list-inside space-y-1">
          <li :for={prompt <- @prompts} class="text-sm">{prompt}</li>
        </ul>
        <p class="text-sm text-gray-600 mt-2">Prompts are selected randomly during processing.</p>
      </div>

      <section class="grid grid-cols-1 gap-4">
        <h2 class="text-lg font-semibold">Last 5 captures</h2>
        <div class="mb-4">
          <.button phx-click="process_recent">Process Recent Sketches</.button>
        </div>
        <div id="sketches" phx-update="stream">
          <.sketch :for={{dom_id, sketch} <- @streams.sketches} sketch={sketch} id={dom_id} />
        </div>
      </section>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      ImaginativeRestorationWeb.Endpoint.subscribe("sketch:updated")
    end

    prompts = Prompt.all_prompts()

    sketches =
      Sketch
      |> Ash.Query.for_read(:read)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(5)
      |> Ash.read!()

    {:ok,
     socket
     |> stream(:sketches, sketches)
     |> assign(prompts: prompts)}
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
end
