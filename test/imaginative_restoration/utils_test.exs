defmodule ImaginativeRestoration.UtilsTest do
  use ImaginativeRestoration.DataCase

  alias ImaginativeRestoration.Sketches
  alias ImaginativeRestoration.Utils

  # Simple fixture for testing
  defp sketch_fixture_dataurl_png do
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="
  end

  defp sketch_fixture_dataurl_webp do
    "data:image/webp;base64,UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAQAcJaQAA3AA/v3AgAAAAA=="
  end

  describe "image conversions" do
    test "to_dataurl!/1 converts PNG data URL to webp" do
      original_png_dataurl = sketch_fixture_dataurl_png()
      webp_dataurl = Utils.to_dataurl!(original_png_dataurl)

      assert String.starts_with?(webp_dataurl, "data:image/webp;base64,")
      refute original_png_dataurl == webp_dataurl
    end

    test "to_dataurl!/1 returns existing webp data URL unchanged" do
      webp_dataurl = sketch_fixture_dataurl_webp()
      assert Utils.to_dataurl!(webp_dataurl) == webp_dataurl
    end

    test "to_image!/1 handles data URL input" do
      dataurl = sketch_fixture_dataurl_png()
      image = Utils.to_image!(dataurl)
      assert %Vix.Vips.Image{} = image
    end
  end

  describe "thumbnail generation" do
    test "creates thumbnail from data URL" do
      dataurl = sketch_fixture_dataurl_png()
      thumbnail_dataurl = Utils.thumbnail!(dataurl, 50)

      assert String.starts_with?(thumbnail_dataurl, "data:image/webp;base64,")
    end
  end

  describe "recent_sketches/1" do
    test "returns empty list when no processed sketches exist" do
      assert Utils.recent_sketches(5) == []
    end

    test "returns sketches with processed images" do
      raw_data = sketch_fixture_dataurl_png()
      {:ok, sketch} = Sketches.init(raw_data)

      # Manually set processed field for test
      processed_sketch =
        sketch
        |> Ash.Changeset.for_update(:process, %{})
        |> Ash.Changeset.force_change_attribute(:processed, "data:image/webp;base64,processed_data")
        |> Ash.update!()

      recent = Utils.recent_sketches(1)
      assert length(recent) == 1
      assert hd(recent).id == processed_sketch.id
    end
  end
end
