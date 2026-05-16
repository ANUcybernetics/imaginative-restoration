defmodule ImaginativeRestoration.UtilsTest do
  use ImaginativeRestoration.DataCase

  alias ImaginativeRestoration.Utils

  @png_bytes Base.decode64!("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=")
  @png_dataurl "data:image/png;base64," <> Base.encode64(@png_bytes)

  describe "data URL helpers" do
    test "decode_dataurl!/1 strips the prefix and decodes base64" do
      assert Utils.decode_dataurl!(@png_dataurl) == @png_bytes
    end

    test "encode_dataurl/2 round-trips with decode_dataurl!/1" do
      encoded = Utils.encode_dataurl(@png_bytes, :png)
      assert String.starts_with?(encoded, "data:image/png;base64,")
      assert Utils.decode_dataurl!(encoded) == @png_bytes
    end
  end

  describe "to_image!/1" do
    test "accepts a data URL" do
      assert %Vix.Vips.Image{} = Utils.to_image!(@png_dataurl)
    end

    test "accepts raw bytes" do
      assert %Vix.Vips.Image{} = Utils.to_image!(@png_bytes)
    end
  end

  describe "to_avif!/2" do
    test "encodes raw bytes as AVIF" do
      avif = Utils.to_avif!(@png_bytes)
      assert is_binary(avif)
      # AVIF magic: bytes 4..11 are "ftypavif" or "ftyp...avif" depending on the brand
      assert byte_size(avif) > 12
      assert binary_part(avif, 4, 4) == "ftyp"
    end
  end

  describe "to_thumbnail_avif!/2" do
    test "produces AVIF thumbnail bytes" do
      thumb = Utils.to_thumbnail_avif!(@png_bytes, 32)
      assert is_binary(thumb)
      assert binary_part(thumb, 4, 4) == "ftyp"
    end
  end

  describe "recent_sketches/1" do
    test "returns empty list when no succeeded sketches exist" do
      assert Utils.recent_sketches(5) == []
    end

    test "returns sketches in :succeeded state" do
      succeeded =
        ImaginativeRestoration.Sketches.Sketch
        |> Ash.Changeset.for_create(:init, %{raw_data: @png_bytes})
        |> Ash.Changeset.force_change_attribute(:state, :succeeded)
        |> Ash.create!()

      assert [^succeeded] = Utils.recent_sketches(1) |> normalise(succeeded)
    end
  end

  defp normalise([sketch], expected), do: if(sketch.id == expected.id, do: [expected], else: [sketch])
end
