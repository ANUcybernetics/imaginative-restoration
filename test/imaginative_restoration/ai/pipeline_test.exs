defmodule ImaginativeRestoration.AI.PipelineTest do
  use ImaginativeRestoration.DataCase

  alias ImaginativeRestoration.AI.Pipeline

  describe "Pipeline.init/1" do
    test "accepts valid :crop_and_label stage" do
      assert {:ok, _opts} = Pipeline.init(stage: :crop_and_label)
    end

    test "accepts valid :process stage" do
      assert {:ok, _opts} = Pipeline.init(stage: :process)
    end

    test "rejects invalid stage" do
      assert {:error, message} = Pipeline.init(stage: :invalid)
      assert message == "stage must be either :crop_and_label or :process"
    end
  end

  describe "Pipeline configuration" do
    test "pipeline stages initialize correctly" do
      assert {:ok, _opts} = Pipeline.init(stage: :crop_and_label)
      assert {:ok, _opts} = Pipeline.init(stage: :process)
    end
  end

  describe "model compatibility" do
    test "new default models are properly configured" do
      # Test that the new models are set as defaults
      raw = ImaginativeRestoration.Fixtures.sketch_dataurl()

      assert {:ok, sketch} = ImaginativeRestoration.Sketches.init(raw)
      assert sketch.model == "black-forest-labs/flux-canny-dev"
    end

    test "legacy models can still be used" do
      raw = ImaginativeRestoration.Fixtures.sketch_dataurl()

      assert {:ok, sketch} =
               ImaginativeRestoration.Sketches.init_with_model(
                 raw,
                 "philz1337x/controlnet-deliberate"
               )

      assert sketch.model == "philz1337x/controlnet-deliberate"
    end
  end
end
