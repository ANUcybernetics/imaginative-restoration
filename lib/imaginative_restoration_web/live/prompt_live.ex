defmodule ImaginativeRestorationWeb.PromptLive do
  @moduledoc false
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
        Current prompt template: <span class="font-semibold"><%= @template %></span>
      </div>

      <.simple_form for={@form} phx-submit="save" phx-change="validate">
        <.input
          type="text"
          field={@form[:template]}
          label="Prompt Template"
          placeholder="Enter prompt template (must include LABEL)"
        />
        <:actions>
          <.button>Save Template</.button>
        </:actions>
      </.simple_form>
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

    form = Prompt |> AshPhoenix.Form.for_create(:create) |> to_form()
    %Prompt{template: template} = ImaginativeRestoration.Sketches.latest_prompt!()

    sketches =
      Sketch
      |> Ash.Query.for_read(:read)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(5)
      |> Ash.read!()

    {:ok,
     socket
     |> stream(:sketches, sketches)
     |> assign(template: template, form: form)}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = socket.assigns.form |> AshPhoenix.Form.validate(params) |> to_form()
    {:noreply, assign(socket, form: form)}
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
        if sketch.label, do: ImaginativeRestoration.Sketches.process!(sketch)
      end,
      timeout: :infinity
    )
    |> Stream.run()

    {:noreply, put_flash(socket, :info, "Processing recent sketches...")}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, %Prompt{template: template}} ->
        form = Prompt |> AshPhoenix.Form.for_create(:create) |> to_form()

        {:noreply,
         socket
         |> put_flash(:info, "Prompt template saved successfully!")
         |> assign(form: form, template: template)}

      {:error, %{errors: [template: {"must match ~r/LABEL/", []}]} = form} ->
        {:noreply,
         socket
         |> put_flash(:error, "The prompt must include the text 'LABEL'")
         |> assign(form: to_form(form))}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error saving prompt template")
         |> assign(form: to_form(form))}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "sketch:updated"} = message, socket) do
    sketch = message.payload.data
    {:noreply, stream_insert(socket, :sketches, sketch, at: 0, limit: 5)}
  end
end
