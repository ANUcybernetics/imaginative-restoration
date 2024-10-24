defmodule ImaginativeRestoration.UtilsTest do
  use ImaginativeRestoration.DataCase

  alias ImaginativeRestoration.AI.Utils

  defp sketch_dataurl do
    File.read!("test/fixtures/sketch.jpg.dataurl")
  end

  describe "jpeg data URL" do
    test "can be converted to webp data URL" do
      # TODO
    end
  end
end
