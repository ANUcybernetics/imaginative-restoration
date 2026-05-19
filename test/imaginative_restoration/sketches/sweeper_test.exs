defmodule ImaginativeRestoration.Sketches.SweeperTest do
  use ImaginativeRestoration.DataCase, async: false

  alias ImaginativeRestoration.AI.Replicate
  alias ImaginativeRestoration.ReplicateStubs
  alias ImaginativeRestoration.Sketches.Sketch
  alias ImaginativeRestoration.Sketches.Sweeper

  @raw_bytes Base.decode64!("UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAQAcJaQAA3AA/v3AgAAAAA==")

  setup do
    # Put Req.Test in shared mode so the application-supervised Sweeper
    # GenServer can see stubs registered by the test process. Also prime the
    # version cache so non-official model submissions don't trigger an
    # unstubbed GET to `/models/.../versions`.
    Req.Test.set_req_test_to_shared(%{})
    ReplicateStubs.prime_version_cache()
    :ok
  end

  defp create_sketch_in_state(state, opts) do
    updated_at = Keyword.get(opts, :updated_at, DateTime.utc_now())
    prediction_id = Keyword.get(opts, :prediction_id, "pred_#{System.unique_integer([:positive])}")
    retry_count = Keyword.get(opts, :retry_count, 0)

    Sketch
    |> Ash.Changeset.for_create(:init, %{raw_data: @raw_bytes})
    |> Ash.Changeset.force_change_attribute(:state, state)
    |> Ash.Changeset.force_change_attribute(:prediction_id, prediction_id)
    |> Ash.Changeset.force_change_attribute(:retry_count, retry_count)
    |> Ash.Changeset.force_change_attribute(:updated_at, updated_at)
    |> Ash.create!()
  end

  describe "sweep_now/0" do
    test "leaves recent sketches alone (not yet stale)" do
      create_sketch_in_state(:generating, updated_at: DateTime.utc_now())

      assert %{still_running: 0, advanced: 0, retried: 0, failed: 0} = Sweeper.sweep_now()
    end

    test "ignores terminal-state sketches" do
      stuck_at = DateTime.add(DateTime.utc_now(), -600, :second)

      _ok = create_sketch_in_state(:succeeded, updated_at: stuck_at)
      _failed = create_sketch_in_state(:failed, updated_at: stuck_at)

      assert %{} = result = Sweeper.sweep_now()
      assert Map.values(result) |> Enum.sum() == 0
    end

    test "skips stale sketches with no prediction_id" do
      stuck_at = DateTime.add(DateTime.utc_now(), -600, :second)
      sketch = create_sketch_in_state(:generating, updated_at: stuck_at, prediction_id: nil)

      assert %{ignored: 1} = Sweeper.sweep_now()

      # The sketch should be left alone (state unchanged) — we couldn't reconcile it.
      reloaded = Ash.get!(Sketch, sketch.id)
      assert reloaded.state == :generating
    end

    test "advances a stuck :generating sketch when Replicate reports succeeded" do
      stuck_at = DateTime.add(DateTime.utc_now(), -600, :second)
      sketch = create_sketch_in_state(:generating, updated_at: stuck_at)

      Req.Test.stub(Replicate, fn
        %{method: "GET"} = conn ->
          Req.Test.json(conn, %{"status" => "succeeded", "output" => "https://example.com/result.jpg"})

        %{method: "POST"} = conn ->
          ReplicateStubs.json_created(conn, %{"id" => "bgrm_new_pred", "status" => "starting"})
      end)

      assert %{advanced: 1} = Sweeper.sweep_now()

      reloaded = Ash.get!(Sketch, sketch.id)
      assert reloaded.state == :removing_background
      assert reloaded.intermediate_image == "https://example.com/result.jpg"
    end

    test "retries a stuck :generating sketch when Replicate reports failed (retry available)" do
      stuck_at = DateTime.add(DateTime.utc_now(), -600, :second)
      sketch = create_sketch_in_state(:generating, updated_at: stuck_at, retry_count: 0)

      Req.Test.stub(Replicate, fn
        %{method: "GET"} = conn ->
          Req.Test.json(conn, %{"status" => "failed", "error" => "Failed to generate image."})

        %{method: "POST"} = conn ->
          ReplicateStubs.json_created(conn, %{"id" => "retry_pred_1", "status" => "starting"})
      end)

      assert %{retried: 1} = Sweeper.sweep_now()

      reloaded = Ash.get!(Sketch, sketch.id)
      assert reloaded.state == :generating
      assert reloaded.retry_count == 1
      assert reloaded.prediction_id == "retry_pred_1"
      assert reloaded.error == nil
    end

    test "fails a stuck :generating sketch when Replicate reports failed and retries are exhausted" do
      stuck_at = DateTime.add(DateTime.utc_now(), -600, :second)
      sketch = create_sketch_in_state(:generating, updated_at: stuck_at, retry_count: Sketch.max_retries())

      Req.Test.stub(Replicate, fn conn ->
        Req.Test.json(conn, %{"status" => "failed", "error" => "Failed to generate image."})
      end)

      assert %{failed: 1} = Sweeper.sweep_now()

      reloaded = Ash.get!(Sketch, sketch.id)
      assert reloaded.state == :failed
      assert reloaded.error =~ "Failed to generate image"
    end

    test "leaves a stuck sketch alone when Replicate says it's still processing" do
      stuck_at = DateTime.add(DateTime.utc_now(), -600, :second)
      sketch = create_sketch_in_state(:generating, updated_at: stuck_at)

      Req.Test.stub(Replicate, fn conn ->
        Req.Test.json(conn, %{"status" => "processing"})
      end)

      assert %{still_running: 1} = Sweeper.sweep_now()

      reloaded = Ash.get!(Sketch, sketch.id)
      assert reloaded.state == :generating
    end

    test "records :errored when Replicate API returns an HTTP error" do
      stuck_at = DateTime.add(DateTime.utc_now(), -600, :second)
      _sketch = create_sketch_in_state(:generating, updated_at: stuck_at)

      Req.Test.stub(Replicate, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, ~s({"detail": "internal server error"}))
      end)

      assert %{errored: 1} = Sweeper.sweep_now()
    end
  end
end
