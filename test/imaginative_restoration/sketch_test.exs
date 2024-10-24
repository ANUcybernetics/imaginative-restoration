defmodule ImaginativeRestoration.SketchTest do
  use ImaginativeRestoration.DataCase

  describe "Sketch resource" do
    @describetag timeout: :timer.minutes(10)

    test "can be created and processed (inc. processing on Replicate)" do
      raw = ImaginativeRestoration.Fixtures.sketch_dataurl()

      assert {:ok, sketch} = ImaginativeRestoration.Sketches.init(raw)
      assert sketch.raw == raw
      assert "adirik/t2i-adapter-sdxl" <> _ = sketch.model
      refute is_nil(sketch.id)

      assert {:ok, processed_sketch} = ImaginativeRestoration.Sketches.process(sketch)
      assert "adirik/t2i-adapter-sdxl" <> _ = processed_sketch.model
      assert String.starts_with?(processed_sketch.processed, "data:image/webp;base64,")
      refute is_nil(processed_sketch.prompt)
    end
  end
end
