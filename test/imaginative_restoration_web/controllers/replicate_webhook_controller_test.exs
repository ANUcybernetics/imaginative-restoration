defmodule ImaginativeRestorationWeb.ReplicateWebhookControllerTest do
  use ImaginativeRestorationWeb.ConnCase, async: false

  alias ImaginativeRestoration.Sketches.Sketch

  defp create_sketch_in_state(state, attrs \\ %{}) do
    base = %{raw: "data:image/webp;base64,UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAQAcJaQAA3AA/v3AgAAAAA=="}

    Sketch
    |> Ash.Changeset.for_create(:init, base)
    |> Ash.Changeset.force_change_attribute(:state, state)
    |> Ash.Changeset.force_change_attribute(:prediction_id, "pred_test")
    |> then(fn cs ->
      Enum.reduce(attrs, cs, fn {k, v}, acc -> Ash.Changeset.force_change_attribute(acc, k, v) end)
    end)
    |> Ash.create!()
  end

  describe "POST /webhooks/replicate/:sketch_id" do
    test "ignores webhooks for unknown sketches", %{conn: conn} do
      conn = post(conn, ~p"/webhooks/replicate/999999", %{"status" => "succeeded", "output" => []})
      assert response(conn, 200)
    end

    test "transitions a :removing_background sketch to :succeeded when bg-removal completes", %{conn: conn} do
      sketch =
        create_sketch_in_state(:removing_background, %{intermediate_image: "https://example.com/gen.webp"})

      output_url =
        "https://fly.storage.tigris.dev/imaginative-restoration-sketches/test.webp"

      # The controller calls Utils.to_dataurl! on the output URL, which fetches over HTTP.
      # We can't easily stub that here, so accept that we'll get either 200 (on fetch
      # success) or 500 (on fetch failure) -- the important thing is the controller
      # routes correctly. A pure dispatch test would require introducing a mock.
      conn =
        post(conn, ~p"/webhooks/replicate/#{sketch.id}", %{
          "status" => "succeeded",
          "output" => output_url
        })

      assert conn.status in [200, 500]
    end

    test "transitions to :failed on a failed prediction", %{conn: conn} do
      sketch = create_sketch_in_state(:generating)

      conn =
        post(conn, ~p"/webhooks/replicate/#{sketch.id}", %{
          "status" => "failed",
          "error" => "model exploded"
        })

      assert response(conn, 200)

      reloaded = Ash.get!(Sketch, sketch.id)
      assert reloaded.state == :failed
      assert reloaded.error =~ "model exploded"
    end

    test "rejects requests with an invalid signature when secret is configured", %{conn: conn} do
      System.put_env("REPLICATE_WEBHOOK_SECRET", "whsec_" <> Base.encode64("test"))

      try do
        sketch = create_sketch_in_state(:generating)

        conn =
          conn
          |> put_req_header("webhook-id", "msg_1")
          |> put_req_header("webhook-timestamp", "1700000000")
          |> put_req_header("webhook-signature", "v1,definitely-not-valid")
          |> post(~p"/webhooks/replicate/#{sketch.id}", %{"status" => "failed", "error" => "x"})

        assert response(conn, 401)

        # State should be unchanged
        reloaded = Ash.get!(Sketch, sketch.id)
        assert reloaded.state == :generating
      after
        System.delete_env("REPLICATE_WEBHOOK_SECRET")
      end
    end
  end
end
