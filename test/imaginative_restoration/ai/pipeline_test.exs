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
    test "new default flux-canny-dev model is properly configured" do
      # Test that the new flux-canny-dev model is set as default
      raw = ImaginativeRestoration.Fixtures.sketch_dataurl()

      assert {:ok, sketch} = ImaginativeRestoration.Sketches.init(raw)
      assert sketch.model == "black-forest-labs/flux-canny-dev"
    end

    test "flux-canny-dev model can be explicitly specified" do
      raw = ImaginativeRestoration.Fixtures.sketch_dataurl()

      # Explicitly test the new model
      assert {:ok, sketch} =
               ImaginativeRestoration.Sketches.init_with_model(
                 raw,
                 "black-forest-labs/flux-canny-dev"
               )

      assert sketch.model == "black-forest-labs/flux-canny-dev"
    end

    test "legacy controlnet-deliberate model can still be used" do
      raw = ImaginativeRestoration.Fixtures.sketch_dataurl()

      assert {:ok, sketch} =
               ImaginativeRestoration.Sketches.init_with_model(
                 raw,
                 "philz1337x/controlnet-deliberate"
               )

      assert sketch.model == "philz1337x/controlnet-deliberate"
    end

    test "new 851-labs background remover is used in pipeline" do
      # Test that the pipeline uses the new background remover model
      # by checking the source code configuration
      {:ok, pipeline_source} = File.read("lib/imaginative_restoration/ai/pipeline.ex")

      # Verify the new background remover model is hardcoded in the pipeline
      assert String.contains?(pipeline_source, "851-labs/background-remover")

      # Verify the old background remover model is no longer used
      refute String.contains?(pipeline_source, "lucataco/remove-bg")
    end
  end
end
