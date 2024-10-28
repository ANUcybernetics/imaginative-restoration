defmodule ImaginativeRestoration.SketchTest do
  use ImaginativeRestoration.DataCase

  alias ImaginativeRestoration.AI.Utils

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

    test "pipeline completes successfully with sketch model" do
      # "adirik/t2i-adapter-sdxl-canny"
      # "adirik/t2i-adapter-sdxl-lineart"
      # "adirik/t2i-adapter-sdxl-sketch"
      raw =
        "test/fixtures/test-sketches/butterfly.png"
        |> Image.open!()
        |> Utils.to_dataurl!()

      model = "adirik/t2i-adapter-sdxl-sketch"

      assert {:ok, sketch} = ImaginativeRestoration.Sketches.init_with_model(raw, model)
      assert sketch.raw == raw
      assert "adirik/t2i-adapter-sdxl" <> _ = sketch.model
      refute is_nil(sketch.id)

      assert {:ok, processed_sketch} = ImaginativeRestoration.Sketches.process(sketch)
      assert processed_sketch.prompt =~ processed_sketch.label

      # now, test some things re: the images

      cropped_image = Utils.to_image!(processed_sketch.cropped)
      IO.puts("cropped_image shape is: #{inspect(Image.shape(cropped_image))}")
      processed_image = Utils.to_image!(processed_sketch.processed)
      IO.puts("processed_image shape is: #{inspect(Image.shape(processed_image))}")
    end
  end
end
