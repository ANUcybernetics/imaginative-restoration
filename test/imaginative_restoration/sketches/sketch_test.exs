defmodule ImaginativeRestoration.Sketches.SketchTest do
  use ImaginativeRestoration.DataCase, async: false

  import Ash.Expr

  alias ImaginativeRestoration.Sketches.Sketch

  require Ash.Query

  # 1x1 WebP — small but valid bytes libvips can decode.
  @raw_bytes Base.decode64!("UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAQAcJaQAA3AA/v3AgAAAAA==")

  defp create_succeeded_sketch(opts \\ []) do
    suffix = Keyword.get(opts, :suffix, "")

    Sketch
    |> Ash.Changeset.for_create(:init, %{raw_data: @raw_bytes})
    |> Ash.Changeset.force_change_attribute(:state, :succeeded)
    |> Ash.Changeset.force_change_attribute(:processed_data, "fake-avif-bytes#{suffix}")
    |> Ash.create!()
  end

  describe "succeeded sketch time-based count queries" do
    setup do
      Sketch
      |> Ash.Query.for_read(:read)
      |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)

      :ok
    end

    test "filter identifies succeeded vs in-progress sketches" do
      succeeded = create_succeeded_sketch()

      _in_progress =
        Sketch
        |> Ash.Changeset.for_create(:init, %{raw_data: @raw_bytes})
        |> Ash.create!()

      succeeded_count =
        Sketch
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(expr(state == :succeeded))
        |> Ash.count!()

      assert succeeded_count == 1
      assert Ash.count!(Sketch) == 2

      [result] =
        Sketch
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(expr(state == :succeeded))
        |> Ash.read!()

      assert result.id == succeeded.id
    end

    test "time-window filters work" do
      create_succeeded_sketch()

      now = DateTime.utc_now()

      for delta_seconds <- [5 * 60, 60 * 60, 24 * 60 * 60] do
        cutoff = DateTime.add(now, -delta_seconds, :second)

        count =
          Sketch
          |> Ash.Query.for_read(:read)
          |> Ash.Query.filter(expr(state == :succeeded and updated_at > ^cutoff))
          |> Ash.count!()

        assert count == 1
      end
    end

    test "far-future window returns no rows" do
      far_future = DateTime.add(DateTime.utc_now(), 100 * 365 * 24, :hour)

      count =
        Sketch
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(expr(updated_at > ^far_future))
        |> Ash.count!()

      assert count == 0
    end
  end
end
