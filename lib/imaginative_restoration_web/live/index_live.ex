defmodule ImaginativeRestorationWeb.IndexLive do
  @moduledoc false
  use ImaginativeRestorationWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      Imaginative Restoration: Rewilding Division
    </div>
    """
  end
end
