defmodule ImaginativeRestoration.AI.Utils do
  @moduledoc false

  def download_to_webp_dataurl(url) do
    url
    |> download_remote_image()
    |> binary_to_dataurl("image/webp")
  end

  def download_remote_image(url) do
    url
    |> Req.get!()
    |> Map.get(:body)
    |> Image.open!()
    |> Image.write!(:memory, suffix: ".webp")
  end

  def binary_to_dataurl(binary, mime_type) do
    binary
    |> Base.encode64()
    |> then(&("data:#{mime_type};base64," <> &1))
  end
end
