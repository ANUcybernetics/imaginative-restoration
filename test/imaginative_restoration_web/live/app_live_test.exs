defmodule ImaginativeRestorationWeb.AppLiveTest do
  use ImaginativeRestorationWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  defp authenticated_conn(conn) do
    auth_header = "Basic " <> Base.encode64("test:test")
    put_req_header(conn, "authorization", auth_header)
  end

  describe "AppLive mounting" do
    test "mounts in display mode correctly", %{conn: conn} do
      {:ok, _view, html} = live(authenticated_conn(conn), "/")
      assert html =~ "sketch-canvas"
      assert html =~ "background-audio"
    end

    test "mounts in capture mode correctly", %{conn: conn} do
      {:ok, _view, html} = live(authenticated_conn(conn), "/?capture=true")
      assert html =~ "sketch-canvas"
      refute html =~ "background-audio"
      assert html =~ "phx-hook=\"WebcamStream\""
    end
  end
end
