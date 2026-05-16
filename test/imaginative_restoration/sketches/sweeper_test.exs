defmodule ImaginativeRestoration.Sketches.SweeperTest do
  use ImaginativeRestoration.DataCase, async: false

  alias ImaginativeRestoration.Sketches.Sketch
  alias ImaginativeRestoration.Sketches.Sweeper

  @raw_bytes Base.decode64!("UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAQAcJaQAA3AA/v3AgAAAAA==")

  defp create_sketch_in_state(state, updated_at) do
    Sketch
    |> Ash.Changeset.for_create(:init, %{raw_data: @raw_bytes})
    |> Ash.Changeset.force_change_attribute(:state, state)
    |> Ash.Changeset.force_change_attribute(:updated_at, updated_at)
    |> Ash.create!()
  end

  describe "sweep_now/0" do
    test "fails sketches stuck in :generating past the cutoff" do
      stuck_at = DateTime.add(DateTime.utc_now(), -600, :second)
      sketch = create_sketch_in_state(:generating, stuck_at)

      assert 1 = Sweeper.sweep_now()

      reloaded = Ash.get!(Sketch, sketch.id)
      assert reloaded.state == :failed
      assert reloaded.error =~ "Timed out"
    end

    test "leaves recent sketches alone" do
      sketch = create_sketch_in_state(:generating, DateTime.utc_now())

      assert 0 = Sweeper.sweep_now()

      reloaded = Ash.get!(Sketch, sketch.id)
      assert reloaded.state == :generating
    end

    test "ignores terminal-state sketches" do
      stuck_at = DateTime.add(DateTime.utc_now(), -600, :second)

      _ok = create_sketch_in_state(:succeeded, stuck_at)
      _failed = create_sketch_in_state(:failed, stuck_at)

      assert 0 = Sweeper.sweep_now()
    end
  end
end
