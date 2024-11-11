defmodule ImaginativeRestorationWeb.PromptLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

  alias ImaginativeRestoration.Sketches.Prompt

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
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
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    form = Prompt |> AshPhoenix.Form.for_create(:create) |> to_form()
    %Prompt{template: template} = ImaginativeRestoration.Sketches.latest_prompt!()

    {:ok, assign(socket, template: template, form: form)}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = socket.assigns.form |> AshPhoenix.Form.validate(params) |> to_form()
    {:noreply, assign(socket, form: form)}
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
end
