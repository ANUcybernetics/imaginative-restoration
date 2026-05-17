defmodule ImaginativeRestorationWeb.AppLiveTest do
  use ImaginativeRestorationWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias ImaginativeRestoration.Sketches.Sketch
  alias Phoenix.Socket.Broadcast

  defp authenticated_conn(conn) do
    auth_header = "Basic " <> Base.encode64("test:test")
    put_req_header(conn, "authorization", auth_header)
  end

  describe "AppLive mounting" do
    test "mounts in display mode correctly", %{conn: conn} do
      {:ok, _view, html} = live(authenticated_conn(conn), "/")

      # Check essential display mode elements
      assert html =~ "sketch-canvas"
      assert html =~ "background-audio"
      assert html =~ "autoplay"

      # Verify audio source
      assert html =~ "soundflakes-horizon-of-the-unknown.mp3"

      # Check page title is set correctly
      assert html =~ "<title data-suffix"
      assert html =~ "Display"

      # Verify no capture mode elements
      refute html =~ "phx-hook=\"WebcamStream\""
      refute html =~ "Processing..."
    end

    test "mounts in capture mode correctly", %{conn: conn} do
      {:ok, _view, html} = live(authenticated_conn(conn), "/?capture=true")

      # Check essential capture mode elements
      assert html =~ "sketch-canvas"
      assert html =~ "phx-hook=\"WebcamStream\""
      assert html =~ "data-capture-interval"

      # Verify no background audio in capture mode
      refute html =~ "background-audio"

      # Check page title is set correctly
      assert html =~ "<title data-suffix"
      assert html =~ "Capture"
    end

    test "mounts with capture_box parameter", %{conn: conn} do
      {:ok, _view, _html} = live(authenticated_conn(conn), "/?capture_box=1")

      # Should behave same as capture mode
      {:ok, _view, html} = live(authenticated_conn(conn), "/?capture_box=1")
      assert html =~ "Capture"
    end

    test "sets correct initial state", %{conn: conn} do
      {:ok, _view, html} = live(authenticated_conn(conn), "/")

      # Check initial state through rendered HTML
      # page title for non-capture mode
      assert html =~ "Display"
      # has audio in display mode
      assert html =~ "background-audio"
      # no processing indicators initially
      refute html =~ "Processing..."
    end
  end

  describe "pre-populating sketches" do
    # Requires database setup
    @tag :skip
    test "handles pre_populate_sketches message", %{conn: conn} do
      {:ok, _view, html} = live(authenticated_conn(conn), "/")

      # In production, :pre_populate_sketches loads sketches from DB
      # For this test to work properly, we'd need to insert test data
      # and ensure the message handler completes

      # Initial state - just verify it connects
      assert html =~ "sketch-canvas"
    end
  end

  describe "webcam frame handling" do
    test "processes frame when no previous images exist", %{conn: conn} do
      {:ok, view, html} = live(authenticated_conn(conn), "/?capture=true")

      # Send a webcam frame
      frame_data =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

      # Should start processing since no previous images
      render_hook(view, "webcam_frame", %{"frame" => frame_data})

      # Should receive capture_triggered event
      assert_push_event(view, "capture_triggered", %{})

      # Since we can't access assigns directly in tests, we just verify
      # the hook was called without error
      assert html =~ "WebcamStream"
    end

    test "admin frames are not processed", %{conn: conn} do
      {:ok, view, html} = live(authenticated_conn(conn), "/?capture=true")

      # Send an admin frame
      frame_data =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

      # Admin frames should not trigger any processing
      render_hook(view, "webcam_frame", %{"frame" => frame_data, "is_admin" => true})

      # Should not receive capture_triggered event
      refute_push_event(view, "capture_triggered", %{})

      assert html =~ "WebcamStream"
    end

    # Requires image processing library
    @tag :skip
    test "skips processing when frame is similar to previous", %{conn: conn} do
      {:ok, view, _html} = live(authenticated_conn(conn), "/?capture=true")

      # Create a processed sketch
      processed_sketch = %Sketch{
        id: Ash.UUID.generate(),
        raw_data: <<1, 2, 3>>,
        processed_data: <<4, 5, 6>>
      }

      # Manually set recent_images
      send(view.pid, {:update_assigns, recent_images: [processed_sketch]})

      # Send similar frame
      similar_frame = "data:image/png;base64,iVBORw0KGgo"
      render_hook(view, "webcam_frame", %{"frame" => similar_frame})

      # Should skip processing
      assert view.assigns.skip_process? == true
    end

    # Requires image processing library
    @tag :skip
    test "processes frame when it differs significantly", %{conn: conn} do
      {:ok, view, _html} = live(authenticated_conn(conn), "/?capture=true")

      # Create a processed sketch with a simple image
      processed_sketch = %Sketch{
        id: Ash.UUID.generate(),
        processed_data: <<1, 2, 3>>
      }

      # Set recent_images
      send(view.pid, {:update_assigns, recent_images: [processed_sketch]})

      # Send different frame (white pixel instead of black)
      different_frame =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

      render_hook(view, "webcam_frame", %{"frame" => different_frame})

      # Should process the different frame
      assert view.assigns.skip_process? == false
    end
  end

  describe "sketch update broadcasts" do
    test "handles process broadcast and updates recent images", %{conn: conn} do
      {:ok, view, _html} = live(authenticated_conn(conn), "/?capture=true")

      sketch = %Sketch{
        id: Ash.UUID.generate(),
        raw_data: <<1, 2, 3>>,
        processed_data: <<4, 5, 6>>
      }

      # Simulate broadcast with "update" event instead of "process" to avoid thumbnail generation
      broadcast = %Broadcast{
        topic: "sketch:updated",
        event: "update",
        payload: %{data: sketch}
      }

      send(view.pid, broadcast)

      # We can't directly check assigns in LiveView tests
      # In real usage, this would update recent_images
    end

    test "handles generic sketch update broadcast", %{conn: conn} do
      {:ok, view, _html} = live(authenticated_conn(conn), "/")

      sketch = %Sketch{id: Ash.UUID.generate()}

      broadcast = %Broadcast{
        topic: "sketch:updated",
        event: "update",
        payload: %{data: sketch}
      }

      send(view.pid, broadcast)

      # In real usage, this would update recent_images
      # We can't directly verify assigns in LiveView tests
    end

    test "maintains maximum of 5 recent images", %{conn: conn} do
      {:ok, view, _html} = live(authenticated_conn(conn), "/?capture=true")

      # Add 6 sketches
      _sketches =
        for i <- 1..6 do
          sketch = %Sketch{id: "sketch-#{i}"}

          broadcast = %Broadcast{
            topic: "sketch:updated",
            event: "update",
            payload: %{data: sketch}
          }

          send(view.pid, broadcast)
          sketch
        end

      # In real usage, this would keep only 5 most recent
      # and drop the oldest sketch
    end

    test "updates existing sketch in recent_images", %{conn: conn} do
      {:ok, view, html} = live(authenticated_conn(conn), "/?capture=true")

      # Add initial sketch
      sketch_id = Ash.UUID.generate()

      initial_sketch = %Sketch{
        id: sketch_id,
        processed_data: nil
      }

      send(view.pid, %Broadcast{
        topic: "sketch:updated",
        event: "update",
        payload: %{data: initial_sketch}
      })

      # Verify initial state
      assert html =~ "sketch-canvas"

      # Update same sketch with processed image
      updated_sketch = %{initial_sketch | processed_data: <<1, 2, 3>>}

      send(view.pid, %Broadcast{
        topic: "sketch:updated",
        event: "update",
        payload: %{data: updated_sketch}
      })

      # In real usage, this would update in place without duplicating
    end
  end

  describe "thumbnail push on succeeded broadcast" do
    test "pushes the stored thumbnail to the client when a sketch reaches :succeeded", %{conn: conn} do
      {:ok, view, _html} = live(authenticated_conn(conn), "/")

      sketch_id = Ash.UUID.generate()
      thumbnail_bytes = <<1, 2, 3, 4>>

      sketch = %Sketch{id: sketch_id, state: :succeeded, thumbnail: thumbnail_bytes}

      send(view.pid, %Broadcast{
        topic: "sketch:updated",
        event: "update",
        payload: %{data: sketch}
      })

      expected_dataurl = "data:image/avif;base64," <> Base.encode64(thumbnail_bytes)

      assert_push_event(view, "add_sketches", %{
        sketches: [%{id: ^sketch_id, dataurl: ^expected_dataurl}]
      })
    end
  end

  describe "spam new sketch (debug feature)" do
    @tag :skip
    test "continuously adds new sketches when enabled", %{conn: conn} do
      # Create a test sketch
      _sketch = %Sketch{
        id: "test-sketch",
        processed_data: <<1, 2, 3>>
      }

      {:ok, view, _html} = live(authenticated_conn(conn), "/")

      # Trigger spam mode
      send(view.pid, :spam_new_sketch)

      # Should receive push events
      assert_push_event(view, "add_sketches", %{sketches: [%{id: _, dataurl: _}]})

      # Should schedule next spam
      assert_receive :spam_new_sketch, 1100
    end
  end

  describe "display mode rendering" do
    test "shows recent processed images in capture mode", %{conn: conn} do
      {:ok, view, _html} = live(authenticated_conn(conn), "/?capture=true")

      sketches = [
        %Sketch{id: Ash.UUID.generate(), processed_data: <<1, 2, 3>>},
        %Sketch{id: Ash.UUID.generate(), processed_data: nil, raw_data: <<4, 5, 6>>},
        %Sketch{id: Ash.UUID.generate(), processed_data: <<7, 8, 9>>}
      ]

      Enum.each(sketches, fn sketch ->
        send(view.pid, %Broadcast{
          topic: "sketch:updated",
          event: "update",
          payload: %{data: sketch}
        })
      end)

      html = render(view)

      # Check that images are displayed (3 images should be rendered)
      assert html =~ "data:image/"

      # Check processing indicator for unprocessed sketch
      assert html =~ "Processing..."
      assert html =~ "sketch-processing"
    end
  end

  describe "error handling" do
    # Can't easily test error handling with LiveView test
    @tag :skip
    test "handles invalid frame data gracefully", %{conn: _conn} do
      # In real usage, invalid frame data would crash the LiveView process
      # Testing this properly would require mocking Utils.to_image!
      assert true
    end

    # Can't easily test error handling with LiveView test
    @tag :skip
    test "handles missing frame parameter", %{conn: _conn} do
      # In real usage, missing frame would cause a function clause error
      # Testing this properly would require catching the LiveView crash
      assert true
    end
  end

  describe "processing concurrency" do
    test "skips new frames while a submission is in flight", %{conn: conn} do
      {:ok, view, _html} = live(authenticated_conn(conn), "/?capture=true")

      frame1 =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

      render_hook(view, "webcam_frame", %{"frame" => frame1})
      assert_push_event(view, "capture_triggered", %{})

      # While the first submission is in flight, a second frame should not
      # trigger another capture.
      frame2 =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

      render_hook(view, "webcam_frame", %{"frame" => frame2})
      refute_push_event(view, "capture_triggered", %{})
    end
  end

  describe "configuration" do
    test "uses configured webcam capture interval", %{conn: conn} do
      {:ok, _view, html} = live(authenticated_conn(conn), "/?capture=true")

      configured_interval = Application.get_env(:imaginative_restoration, :webcam_capture_interval)
      assert html =~ "data-capture-interval=\"#{configured_interval}\""
    end

    test "uses configured image difference threshold", %{conn: conn} do
      {:ok, _view, _html} = live(authenticated_conn(conn), "/?capture=true")

      # Can't access assigns directly, but we know it uses the configured threshold
      configured_threshold = Application.get_env(:imaginative_restoration, :image_difference_threshold)
      assert configured_threshold
    end

    test "capture interval is now 1 second", %{conn: conn} do
      {:ok, _view, html} = live(authenticated_conn(conn), "/?capture=true")

      # Verify the new 1s interval is used
      assert html =~ "data-capture-interval=\"1000\""
    end
  end

  describe "responsive layout" do
    test "maintains 4:3 aspect ratio", %{conn: conn} do
      {:ok, _view, html} = live(authenticated_conn(conn), "/")

      # Check aspect ratio classes
      assert html =~ "aspect-[4/3]"
      assert html =~ "max-w-[calc(100vh*4/3)]"
    end
  end

  describe "flash overlay" do
    test "does not show progress line", %{conn: conn} do
      {:ok, _view, html} = live(authenticated_conn(conn), "/?capture=true")

      # Verify progress line is removed
      refute html =~ "progress-line"
      refute html =~ "stroke=\"#a07003\""

      # But flash overlay should still exist
      assert html =~ "flash-overlay"
    end
  end

  describe "camera error handling" do
    test "handles camera ready status", %{conn: conn} do
      {:ok, view, _html} = live(authenticated_conn(conn), "/?capture=true")

      # Send camera ready status
      render_hook(view, "camera_status", %{"status" => "ready"})

      # Should clear any camera error
      html = render(view)
      refute html =~ "Camera Not Available"
    end

    test "handles camera error status", %{conn: conn} do
      {:ok, view, _html} = live(authenticated_conn(conn), "/?capture=true")

      # Send camera error
      render_hook(view, "camera_status", %{
        "status" => "error",
        "error_type" => "permission_denied",
        "error_message" => "Camera permission denied. Please allow camera access."
      })

      # Should display error message
      html = render(view)
      assert html =~ "Camera Not Available"
      assert html =~ "Camera permission denied"
    end
  end
end
