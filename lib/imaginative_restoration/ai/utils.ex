defmodule ImaginativeRestoration.AI.Utils do
  @moduledoc false

  def download_to_webp_dataurl(url) do
    url
    |> download_remote_image()
    |> image_to_dataurl("webp")
  end

  def download_remote_image(url) do
    url
    |> Req.get!()
    |> Map.get(:body)
    |> Image.open!()
    |> Image.write!(:memory, suffix: ".webp")
  end

  def image_to_dataurl(image, format) do
    image
    |> Base.encode64()
    |> then(&("data:image/#{format};base64," <> &1))
  end

  def convert_dataurl(dataurl, format) do
    dataurl
    |> String.split(",", parts: 2)
    |> List.last()
    |> Base.decode64!()
    |> Image.open!()
    |> Image.write!(:memory, suffix: ".#{format}")
    |> image_to_dataurl(format)
  end
end
