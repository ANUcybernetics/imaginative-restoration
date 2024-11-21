defmodule ImaginativeRestoration.Utils do
  @moduledoc false

  alias ImaginativeRestoration.Sketches.Sketch

  require Ash.Query

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
    |> Image.write!(:memory, suffix: ".webp", effort: 10)
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

  def thumbnail!("data:image/" <> _ = dataurl, length \\ 300) do
    dataurl
    |> to_image!()
    |> Image.thumbnail!(length)
    |> to_dataurl!()
  end

  def upload_to_s3!(%Vix.Vips.Image{} = image, filename) do
    # Convert image to binary
    image_binary = Image.write!(image, :memory, suffix: ".webp")

    # Upload to S3
    response =
      Req.new()
      |> ReqS3.attach()
      |> Req.put!(
        url: "s3://imaginative-restoration-sketches/#{filename}",
        body: image_binary
      )

    case response do
      %{status: status} when status in 200..299 ->
        {:ok, "https://fly.storage.tigris.dev/imaginative-restoration-sketches/#{filename}"}

      _ ->
        {:error, "Failed to upload image"}
    end
  end

  def recent_sketches(count) do
    Sketch
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(not is_nil(processed))
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(count)
    |> Ash.read!()
  end

  def changed_recently? do
    raw_images = 5 |> recent_sketches() |> Enum.map(&to_image!(&1.raw))
    difference_threshold = 15

    distances =
      raw_images
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] ->
        {:ok, d} = Image.hamming_distance(a, b)
        d
      end)

    # if any of the distances are greater than 0, then the target image has changed recently
    not Enum.all?(distances, fn d -> d < difference_threshold end)
  end
end
