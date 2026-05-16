defmodule ImaginativeRestoration.SketchTest do
  use ImaginativeRestoration.DataCase

  alias ImaginativeRestoration.Sketches

  @raw_bytes Base.decode64!("UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAQAcJaQAA3AA/v3AgAAAAA==")

  describe "Sketch resource - creation" do
    test "init/1 successfully creates a sketch with default model" do
      assert {:ok, sketch} = Sketches.init(@raw_bytes)

      assert sketch.raw_data == @raw_bytes
      assert sketch.model == "black-forest-labs/flux-canny-dev"
      assert is_nil(sketch.processed_data)
      assert is_nil(sketch.thumbnail)
      assert is_nil(sketch.prompt)
      assert sketch.hidden == false
      assert is_integer(sketch.id)
    end

    test "init_with_model/2 successfully creates a sketch with a custom model" do
      custom_model = "custom/test-model"
      assert {:ok, sketch} = Sketches.init_with_model(@raw_bytes, custom_model)

      assert sketch.raw_data == @raw_bytes
      assert sketch.model == custom_model
    end

    test "init/1 fails if raw_data is nil" do
      assert {:error, _} = Sketches.init(nil)
    end
  end
end
