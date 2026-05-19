defmodule ImaginativeRestorationWeb.ReplicateWebhookControllerTest do
  use ImaginativeRestorationWeb.ConnCase, async: false

  alias ImaginativeRestoration.AI.Replicate
  alias ImaginativeRestoration.ReplicateStubs
  alias ImaginativeRestoration.Sketches.Sketch

  setup do
    Req.Test.set_req_test_to_shared(%{})
    ReplicateStubs.prime_version_cache()
    :ok
  end

  @raw_bytes Base.decode64!("UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAQAcJaQAA3AA/v3AgAAAAA==")

  defp create_sketch_in_state(state, attrs \\ %{}) do
    Sketch
    |> Ash.Changeset.for_create(:init, %{raw_data: @raw_bytes})
    |> Ash.Changeset.force_change_attribute(:state, state)
    |> Ash.Changeset.force_change_attribute(:prediction_id, "pred_test")
    |> then(fn cs ->
      Enum.reduce(attrs, cs, fn {k, v}, acc -> Ash.Changeset.force_change_attribute(acc, k, v) end)
    end)
    |> Ash.create!()
  end

  describe "POST /webhooks/replicate/:sketch_id" do
    test "returns 200 for webhooks targeting unknown sketches", %{conn: conn} do
      conn = post(conn, ~p"/webhooks/replicate/999999", %{"status" => "succeeded", "output" => []})
      assert response(conn, 200)
    end

    test "advances a :generating sketch on a succeeded webhook", %{conn: conn} do
      sketch = create_sketch_in_state(:generating)

      Req.Test.stub(Replicate, fn
        %{method: "POST"} = http_conn ->
          ReplicateStubs.json_created(http_conn, %{"id" => "bgrm_pred", "status" => "starting"})
      end)

      conn =
        post(conn, ~p"/webhooks/replicate/#{sketch.id}", %{
          "status" => "succeeded",
          "output" => "https://example.com/gen.jpg"
        })

      assert response(conn, 200)

      reloaded = Ash.get!(Sketch, sketch.id)
      assert reloaded.state == :removing_background
    end

    test "retries on a failed webhook when retry budget remains", %{conn: conn} do
      sketch = create_sketch_in_state(:generating, %{retry_count: 0})

      Req.Test.stub(Replicate, fn
        %{method: "POST"} = http_conn ->
          ReplicateStubs.json_created(http_conn, %{"id" => "retry_pred", "status" => "starting"})
      end)

      conn =
        post(conn, ~p"/webhooks/replicate/#{sketch.id}", %{
          "status" => "failed",
          "error" => "Failed to generate image."
        })

      assert response(conn, 200)

      reloaded = Ash.get!(Sketch, sketch.id)
      assert reloaded.state == :generating
      assert reloaded.retry_count == 1
    end

    test "transitions to :failed when retries are exhausted", %{conn: conn} do
      sketch = create_sketch_in_state(:generating, %{retry_count: Sketch.max_retries()})

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

        reloaded = Ash.get!(Sketch, sketch.id)
        assert reloaded.state == :generating
      after
        System.delete_env("REPLICATE_WEBHOOK_SECRET")
      end
    end
  end
end
