defmodule ImaginativeRestorationWeb.AppLiveTest do
  use ImaginativeRestorationWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias ImaginativeRestoration.Sketches.Sketch
  alias Phoenix.PubSub
  alias Phoenix.Socket.Broadcast

  defp authenticated_conn(conn) do
    auth_header = "Basic " <> Base.encode64("test:test")
    put_req_header(conn, "authorization", auth_header)
  end

  describe "AppLive" do
    test "mounts successfully in display mode", %{conn: conn} do
      {:ok, _view, html} = live(authenticated_conn(conn), "/")
      assert html =~ "sketch-canvas"
      assert html =~ "background-audio"
    end

    test "mounts successfully in capture mode", %{conn: conn} do
      {:ok, _view, html} = live(authenticated_conn(conn), "/?capture=true")
      assert html =~ "sketch-canvas"
      refute html =~ "background-audio"
      # In capture mode, webcam capture video element should be present
      assert html =~ "phx-hook=\"WebcamStream\""
    end

    test "handles sketch broadcast and generates thumbnail asynchronously", %{conn: conn} do
      {:ok, view, _html} = live(authenticated_conn(conn), "/")

      # Create a mock sketch with processed image data
      sketch = %Sketch{
        id: 123,
        raw: "data:image/webp;base64,UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAwA0JaQAA3AA/vuUAAA=",
        processed: "data:image/webp;base64,UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAwA0JaQAA3AA/vuUAAA=",
        model: "test-model",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      # Initially no sketch assigned - we'll verify by checking that no sketch processing message appears
      html = render(view)
      refute html =~ "Processing..."

      # Broadcast the sketch update with "process" event
      PubSub.broadcast(
        ImaginativeRestoration.PubSub,
        "sketch:updated",
        %Broadcast{
          topic: "sketch:updated",
          event: "process",
          payload: %{data: sketch}
        }
      )

      # Wait a moment for the LiveView to process the broadcast
      :timer.sleep(10)

      # Verify the sketch was processed by checking for expected content
      # We can't easily access assigns in tests, so we verify through behavior

      # Wait for the async thumbnail generation task to complete
      # and send the thumbnail_ready message back to the LiveView
      :timer.sleep(200)

      # Assert that the add_sketches event was pushed to the client
      # and verify the thumbnail dataurl was generated properly
      assert_push_event(view, "add_sketches", %{
        sketches: [sketch_data]
      })

      assert %{id: 123, dataurl: dataurl} = sketch_data
      assert is_binary(dataurl)
      assert String.starts_with?(dataurl, "data:")
    end

    test "handles regular sketch broadcast without thumbnail generation", %{conn: conn} do
      {:ok, view, _html} = live(authenticated_conn(conn), "/")

      sketch = %Sketch{
        id: 456,
        raw: "data:image/webp;base64,UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAwA0JaQAA3AA/vuUAAA=",
        processed: nil,
        model: "test-model",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      # Broadcast a regular sketch update (not "process" event)
      PubSub.broadcast(
        ImaginativeRestoration.PubSub,
        "sketch:updated",
        %Broadcast{
          topic: "sketch:updated",
          event: "update",
          payload: %{data: sketch}
        }
      )

      # Wait a moment for processing
      :timer.sleep(10)

      # Verify the sketch was received (we can't easily check assigns in tests)
      # Wait a bit longer to ensure no async task is triggered
      :timer.sleep(100)

      # No add_sketches event should be pushed for non-"process" events
      refute_push_event(view, "add_sketches", %{})
    end

    test "handles thumbnail_ready message directly", %{conn: conn} do
      {:ok, view, _html} = live(authenticated_conn(conn), "/")

      sketch = %Sketch{
        id: 789,
        raw: "data:image/webp;base64,test_raw",
        processed: "data:image/webp;base64,test_processed",
        model: "test-model",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      thumbnail_dataurl = "data:image/webp;base64,test_thumbnail"

      # Send thumbnail_ready message directly to the LiveView process
      send(view.pid, {:thumbnail_ready, sketch, thumbnail_dataurl})

      # Wait a moment for processing
      :timer.sleep(10)

      # Assert that the add_sketches event was pushed
      assert_push_event(view, "add_sketches", %{
        sketches: [%{id: 789, dataurl: "data:image/webp;base64,test_thumbnail"}]
      })
    end

    test "pre-populates sketches on mount when connected", %{conn: conn} do
      # Create some test sketches first (this would normally come from the database)
      {:ok, view, _html} = live(authenticated_conn(conn), "/")

      # Wait for the pre-populate timer to fire
      :timer.sleep(1100)

      # The pre-populate function should try to load recent sketches
      # Since we don't have real sketches in the test DB, this will likely be empty
      # but we can verify the LiveView is still responsive
      html = render(view)
      assert html =~ "sketch-canvas"
    end

    test "assigns correct initial state based on URL params", %{conn: conn} do
      # Test with capture parameter
      {:ok, _view1, html1} = live(authenticated_conn(conn), "/?capture=true")
      # Should not have audio in capture mode
      refute html1 =~ "background-audio"
      # Should have webcam capture video element
      assert html1 =~ "phx-hook=\"WebcamStream\""

      # Test with capture_box parameter
      {:ok, _view2, html2} = live(authenticated_conn(conn), "/?capture_box=true")
      # Should not have audio in capture mode
      refute html2 =~ "background-audio"
      # Should have webcam capture video element
      assert html2 =~ "phx-hook=\"WebcamStream\""

      # Test without capture parameters
      {:ok, _view3, html3} = live(authenticated_conn(conn), "/")
      # Should have audio in display mode
      assert html3 =~ "background-audio"
      # Should not have webcam capture in display mode
      refute html3 =~ "phx-hook=\"WebcamStream\""
    end
  end
end
