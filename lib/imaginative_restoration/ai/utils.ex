defmodule ImaginativeRestoration.AI.Utils do
  @moduledoc false

  def to_image!(%Vix.Vips.Image{} = image), do: image

  def to_image!("http" <> _ = url) do
    url
    |> Req.get!()
    |> Map.get(:body)
    |> Image.open!()
  end

  def to_image!("data:image/" <> _ = dataurl) do
    dataurl
    |> String.split(",", parts: 2)
    |> List.last()
    |> Base.decode64!()
    |> Image.open!()
  end

  def to_dataurl!(%Vix.Vips.Image{} = image) do
    image
    |> Image.write!(:memory, suffix: ".webp")
    |> Base.encode64()
    |> then(&("data:image/webp;base64," <> &1))
  end

  def to_dataurl!("http" <> _ = url) do
    url
    |> to_image!()
    |> to_dataurl!()
  end

  def to_dataurl!("data:image/webp" <> _ = dataurl), do: dataurl

  # convert other dataurls to webp
  def to_dataurl!("data:image/" <> _ = dataurl) do
    dataurl
    |> to_image!()
    |> to_dataurl!()
  end

  def crop!("data:image/" <> _ = dataurl, x, y, w, h) do
    dataurl
    |> to_image!()
    |> crop!(x, y, w, h)
  end

  def crop!(%Vix.Vips.Image{} = image, x, y, w, h) do
    Image.crop!(image, x, y, w, h)
  end
end
