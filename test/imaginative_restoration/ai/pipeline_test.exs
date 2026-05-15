defmodule ImaginativeRestoration.AI.PipelineTest do
  use ImaginativeRestoration.DataCase

  alias ImaginativeRestoration.AI.Pipeline

  describe "init/1" do
    test "returns :ok for valid stages" do
      assert {:ok, [stage: :submit_generation]} = Pipeline.init(stage: :submit_generation)
      assert {:ok, [stage: :submit_bg_removal]} = Pipeline.init(stage: :submit_bg_removal)
    end

    test "returns :error for invalid stage" do
      assert {:error, _} = Pipeline.init(stage: :invalid_stage)
    end
  end
end
