defmodule ImaginativeRestoration.AI.PipelineTest do
  use ImaginativeRestoration.DataCase

  alias ImaginativeRestoration.AI.Pipeline

  describe "init/1" do
    test "returns :ok for valid stages" do
      assert {:ok, [stage: :process]} = Pipeline.init(stage: :process)
      assert {:ok, [stage: :crop_and_label]} = Pipeline.init(stage: :crop_and_label)
    end

    test "returns :error for invalid stage" do
      assert {:error, "stage must be either :crop_and_label or :process"} =
               Pipeline.init(stage: :invalid_stage)
    end
  end
end
