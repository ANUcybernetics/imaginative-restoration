defmodule ImaginativeRestoration.Sketches.AdvanceTest do
  use ImaginativeRestoration.DataCase, async: false

  alias ImaginativeRestoration.AI.Replicate
  alias ImaginativeRestoration.ReplicateStubs
  alias ImaginativeRestoration.Sketches.Advance
  alias ImaginativeRestoration.Sketches.Sketch

  setup do
    Req.Test.set_req_test_to_shared(%{})
    ReplicateStubs.prime_version_cache()
    :ok
  end

  @raw_bytes Base.decode64!("UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAQAcJaQAA3AA/v3AgAAAAA==")

  defp sketch_in_state(state, opts \\ []) do
    retry_count = Keyword.get(opts, :retry_count, 0)

    Sketch
    |> Ash.Changeset.for_create(:init, %{raw_data: @raw_bytes})
    |> Ash.Changeset.force_change_attribute(:state, state)
    |> Ash.Changeset.force_change_attribute(:prediction_id, "pred_test")
    |> Ash.Changeset.force_change_attribute(:retry_count, retry_count)
    |> Ash.create!()
  end

  describe "advance/2 on :generating sketches" do
    test "succeeded payload drives forward to :removing_background" do
      sketch = sketch_in_state(:generating)

      Req.Test.stub(Replicate, fn
        %{method: "POST"} = conn ->
          ReplicateStubs.json_created(conn, %{"id" => "bgrm_pred", "status" => "starting"})
      end)

      assert {:ok, :advanced} =
               Advance.advance(sketch, %{
                 "status" => "succeeded",
                 "output" => "https://example.com/out.jpg"
               })

      reloaded = Ash.get!(Sketch, sketch.id)
      assert reloaded.state == :removing_background
      assert reloaded.intermediate_image == "https://example.com/out.jpg"
    end

    test "failed payload triggers retry when retry budget remains" do
      sketch = sketch_in_state(:generating, retry_count: 0)

      Req.Test.stub(Replicate, fn
        %{method: "POST"} = conn ->
          ReplicateStubs.json_created(conn, %{"id" => "retry_pred", "status" => "starting"})
      end)

      assert {:ok, :retried} =
               Advance.advance(sketch, %{"status" => "failed", "error" => "Failed to generate image."})

      reloaded = Ash.get!(Sketch, sketch.id)
      assert reloaded.state == :generating
      assert reloaded.retry_count == 1
      assert reloaded.prediction_id == "retry_pred"
    end

    test "failed payload transitions to :failed when retries are exhausted" do
      sketch = sketch_in_state(:generating, retry_count: Sketch.max_retries())

      assert {:ok, :failed} =
               Advance.advance(sketch, %{"status" => "failed", "error" => "Failed to generate image."})

      reloaded = Ash.get!(Sketch, sketch.id)
      assert reloaded.state == :failed
      assert reloaded.error =~ "Failed to generate image"
    end

    test "canceled never retries" do
      sketch = sketch_in_state(:generating, retry_count: 0)

      assert {:ok, :failed} = Advance.advance(sketch, %{"status" => "canceled"})

      reloaded = Ash.get!(Sketch, sketch.id)
      assert reloaded.state == :failed
    end

    test "processing/starting are no-ops" do
      sketch = sketch_in_state(:generating)

      assert {:ok, :still_running} = Advance.advance(sketch, %{"status" => "processing"})
      assert {:ok, :still_running} = Advance.advance(sketch, %{"status" => "starting"})

      reloaded = Ash.get!(Sketch, sketch.id)
      assert reloaded.state == :generating
    end
  end

  describe "advance/2 on terminal-state sketches" do
    test "success payload arriving after sketch is already :succeeded is ignored" do
      sketch =
        Sketch
        |> Ash.Changeset.for_create(:init, %{raw_data: @raw_bytes})
        |> Ash.Changeset.force_change_attribute(:state, :succeeded)
        |> Ash.create!()

      assert {:ok, :ignored} =
               Advance.advance(sketch, %{"status" => "succeeded", "output" => "https://example.com/x.jpg"})
    end

    test "failure payload arriving after sketch is already :failed is ignored" do
      sketch =
        Sketch
        |> Ash.Changeset.for_create(:init, %{raw_data: @raw_bytes})
        |> Ash.Changeset.force_change_attribute(:state, :failed)
        |> Ash.create!()

      assert {:ok, :ignored} = Advance.advance(sketch, %{"status" => "failed", "error" => "x"})
    end
  end

  describe "advance/2 on unrecognised payloads" do
    test "missing status field" do
      sketch = sketch_in_state(:generating)

      assert {:ok, :ignored} = Advance.advance(sketch, %{"foo" => "bar"})
    end
  end
end
