defmodule ImaginativeRestoration.SketchTest do
  use ImaginativeRestoration.DataCase

  alias ImaginativeRestoration.Utils

  describe "Sketch resource" do
    @describetag skip: "makes real API calls"
    @describetag timeout: :timer.minutes(10)

    test "can be created and processed (inc. processing on Replicate)" do
      raw = ImaginativeRestoration.Fixtures.sketch_dataurl()

      assert {:ok, sketch} = ImaginativeRestoration.Sketches.init(raw)
      assert sketch.raw == raw
      assert "black-forest-labs/flux-canny-dev" <> _ = sketch.model
      refute is_nil(sketch.id)

      assert {:ok, processed_sketch} = ImaginativeRestoration.Sketches.process(sketch)
      assert "black-forest-labs/flux-canny-dev" <> _ = processed_sketch.model
      assert String.starts_with?(processed_sketch.processed, "data:image/webp;base64,")
      refute is_nil(processed_sketch.prompt)
    end

    test "can be created with legacy models for backwards compatibility" do
      raw = ImaginativeRestoration.Fixtures.sketch_dataurl()

      assert {:ok, sketch} =
               ImaginativeRestoration.Sketches.init_with_model(
                 raw,
                 "philz1337x/controlnet-deliberate"
               )

      assert sketch.raw == raw
      assert sketch.model == "philz1337x/controlnet-deliberate"
      refute is_nil(sketch.id)

      assert {:ok, processed_sketch} = ImaginativeRestoration.Sketches.process(sketch)
      assert processed_sketch.model == "philz1337x/controlnet-deliberate"
      assert String.starts_with?(processed_sketch.processed, "data:image/webp;base64,")
      refute is_nil(processed_sketch.prompt)
    end

    test "uses new background remover model by default" do
      raw = ImaginativeRestoration.Fixtures.sketch_dataurl()

      assert {:ok, sketch} = ImaginativeRestoration.Sketches.init(raw)

      # Processing should complete successfully with new background remover
      assert {:ok, processed_sketch} = ImaginativeRestoration.Sketches.process(sketch)
      assert String.starts_with?(processed_sketch.processed, "data:image/webp;base64,")
    end

    test "pipeline completes successfully with sketch model" do
      # "adirik/t2i-adapter-sdxl-canny"
      # "adirik/t2i-adapter-sdxl-lineart"
      # "adirik/t2i-adapter-sdxl-sketch"
      raw =
        "test/fixtures/test-sketches/butterfly.png"
        |> Image.open!()
        |> Utils.to_dataurl!()

      model = "black-forest-labs/flux-canny-dev"

      assert {:ok, sketch} = ImaginativeRestoration.Sketches.init_with_model(raw, model)
      assert sketch.raw == raw
      assert "black-forest-labs/flux-canny-dev" <> _ = sketch.model
      refute is_nil(sketch.id)

      assert {:ok, processed_sketch} = ImaginativeRestoration.Sketches.process(sketch)
      assert processed_sketch.prompt =~ processed_sketch.label

      # now, test some things re: the images

      cropped_image = Utils.to_image!(processed_sketch.cropped)
      IO.puts("cropped_image shape is: #{inspect(Image.shape(cropped_image))}")
      processed_image = Utils.to_image!(processed_sketch.processed)
      IO.puts("processed_image shape is: #{inspect(Image.shape(processed_image))}")
    end

    test "new default models are used correctly" do
      raw =
        "test/fixtures/test-sketches/butterfly.png"
        |> Image.open!()
        |> Utils.to_dataurl!()

      # Test new defaults
      assert {:ok, sketch} = ImaginativeRestoration.Sketches.init(raw)
      assert sketch.model == "black-forest-labs/flux-canny-dev"

      assert {:ok, processed_sketch} = ImaginativeRestoration.Sketches.process(sketch)
      assert processed_sketch.model == "black-forest-labs/flux-canny-dev"
    end

    test "legacy models still work" do
      raw =
        "test/fixtures/test-sketches/butterfly.png"
        |> Image.open!()
        |> Utils.to_dataurl!()

      # Test with legacy models
      assert {:ok, sketch} =
               ImaginativeRestoration.Sketches.init_with_model(
                 raw,
                 "philz1337x/controlnet-deliberate"
               )

      assert sketch.model == "philz1337x/controlnet-deliberate"

      assert {:ok, processed_sketch} = ImaginativeRestoration.Sketches.process(sketch)
      assert processed_sketch.model == "philz1337x/controlnet-deliberate"
    end
  end
end
