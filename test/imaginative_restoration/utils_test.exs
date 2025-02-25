defmodule ImaginativeRestoration.UtilsTest do
  use ImaginativeRestoration.DataCase

  alias ImaginativeRestoration.Utils

  describe "image conversions" do
    test "http URL can be converted to webp data URL" do
      sketch_url = "https://fly.storage.tigris.dev/imaginative-restoration-sketches/bird-flight-sketch.png"

      result = Utils.to_dataurl!(sketch_url)

      assert String.starts_with?(result, "data:image/webp;base64,")
      # Ensure we got meaningful data
      assert String.length(result) > 100
    end

    test "image data URL can be converted to webp" do
      jpg = ImaginativeRestoration.Fixtures.sketch_dataurl()

      result = Utils.to_dataurl!(jpg)

      assert String.starts_with?(result, "data:image/webp;base64,")
      assert String.length(result) > 100
    end
  end
end
