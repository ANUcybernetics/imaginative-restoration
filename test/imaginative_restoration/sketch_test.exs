defmodule ImaginativeRestoration.SketchTest do
  use ImaginativeRestoration.DataCase

  describe "Sketch resource" do
    @describetag timeout: :timer.minutes(10)

    test "can be created and processed (inc. processing on Replicate)" do
      unprocessed = ImaginativeRestoration.Fixtures.sketch_dataurl()

      assert {:ok, sketch} = ImaginativeRestoration.Sketches.init(unprocessed)
      assert sketch.unprocessed == unprocessed
      assert "adirik/t2i-adapter-sdxl" <> _ = sketch.model
      refute is_nil(sketch.id)

      assert {:ok, processed} = ImaginativeRestoration.Sketches.process(sketch)
      assert "adirik/t2i-adapter-sdxl" <> _ = processed.model
      refute is_nil(processed.processed)
      refute is_nil(processed.prompt)
    end
  end
end
