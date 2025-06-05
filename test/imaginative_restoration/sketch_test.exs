defmodule ImaginativeRestoration.SketchTest do
  use ImaginativeRestoration.DataCase

  alias ImaginativeRestoration.Sketches

  # Simple fixture for testing
  defp sketch_dataurl_fixture do
    "data:image/webp;base64,UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAQAcJaQAA3AA/v3AgAAAAA=="
  end

  describe "Sketch resource - creation" do
    test "init/1 successfully creates a sketch with default model" do
      raw_data = sketch_dataurl_fixture()
      assert {:ok, sketch} = Sketches.init(raw_data)

      assert sketch.raw == raw_data
      assert sketch.model == "black-forest-labs/flux-canny-dev"
      assert is_nil(sketch.processed)
      assert is_nil(sketch.prompt)
      assert sketch.hidden == false
      assert is_integer(sketch.id)
    end

    test "init_with_model/2 successfully creates a sketch with a custom model" do
      raw_data = sketch_dataurl_fixture()
      custom_model = "custom/test-model"
      assert {:ok, sketch} = Sketches.init_with_model(raw_data, custom_model)

      assert sketch.raw == raw_data
      assert sketch.model == custom_model
    end

    test "init/1 fails if raw data is empty or nil" do
      assert {:error, _} = Sketches.init("")
      assert {:error, _} = Sketches.init(nil)
    end
  end

  describe "Sketch resource - basic functionality" do
    test "can create sketch successfully" do
      raw_data = sketch_dataurl_fixture()
      assert {:ok, sketch} = Sketches.init(raw_data)
      assert sketch.raw == raw_data
      assert sketch.model == "black-forest-labs/flux-canny-dev"
    end
  end
end
