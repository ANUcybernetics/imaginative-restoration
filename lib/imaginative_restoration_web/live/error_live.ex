defmodule ImaginativeRestorationWeb.ErrorLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-[50vh] text-center px-4">
      <h1 class="text-4xl font-bold mb-4">
        Whoops.
      </h1>
      <p class="text-zinc-600 mb-8">
        An error occurred.
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
