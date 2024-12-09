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

  def write_image_from_db(id, attribute \\ :processed) do
    filename = "#{id}-#{attribute}.webp"

    Sketch
    |> Ash.get!(id)
    |> Map.get(attribute)
    |> ImaginativeRestoration.Utils.to_image!()
    |> Image.write!(filename)

    IO.puts("Image has been written to #{filename}")
  end

  def recent_sketches(count) do
    Sketch
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(not is_nil(processed))
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(count)
    |> Ash.read!()
  end

  def inter_image_distances(images) do
    images
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] ->
      {:ok, d} = Image.hamming_distance(a, b)
      d
    end)
  end

  def changed_recently?(latest_raw_image) do
    difference_threshold = Application.get_env(:imaginative_restoration, :no_change_threshold)
    number_of_images = Application.get_env(:imaginative_restoration, :no_change_images)

    distances =
      number_of_images
      |> recent_sketches()
      |> Enum.map(&to_image!(&1.raw))
      |> List.insert_at(0, latest_raw_image)
      |> inter_image_distances()

    # if any of the distances are greater than 0, then the target image has changed recently
    Enum.any?(distances, fn d -> d > difference_threshold end)
  end
end
