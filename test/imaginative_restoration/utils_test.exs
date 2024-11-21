defmodule ImaginativeRestoration.UtilsTest do
  use ImaginativeRestoration.DataCase

  alias ImaginativeRestoration.Utils

  describe "png data URL" do
    test "can be converted to webp data URL" do
      # raw = ImaginativeRestoration.Fixtures.sketch_dataurl()
      sketch_url = "https://fly.storage.tigris.dev/imaginative-restoration-sketches/bird-flight-sketch.png"

      result = Utils.download_to_webp_dataurl(sketch_url)

      assert String.starts_with?(result, "data:image/webp;base64,")
      # Ensure we got meaningful data
      assert String.length(result) > 100
    end

    test "jpg data URL can be converted to webp" do
      jpg = ImaginativeRestoration.Fixtures.sketch_dataurl()

      result = Utils.convert_dataurl(jpg, "webp")

      assert String.starts_with?(result, "data:image/webp;base64,")
      assert String.length(result) > 100
    end
  end
end
