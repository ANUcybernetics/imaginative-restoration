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
    |> decode_dataurl!()
    |> Image.open!()
  end

  def to_image!(bytes) when is_binary(bytes), do: Image.open!(bytes)

  @doc """
  Strips the `data:image/<format>;base64,` prefix from a data URL and returns
  the raw image bytes.
  """
  @spec decode_dataurl!(String.t()) :: binary()
  def decode_dataurl!("data:image/" <> _ = dataurl) do
    dataurl
    |> String.split(",", parts: 2)
    |> List.last()
    |> Base.decode64!()
  end

  @doc """
  Wraps raw image bytes in a `data:image/<format>;base64,` URL for inline
  rendering in HTML.
  """
  @spec encode_dataurl(binary(), atom() | String.t()) :: String.t()
  def encode_dataurl(bytes, format) when is_binary(bytes) do
    "data:image/#{format};base64," <> Base.encode64(bytes)
  end

  @doc """
  Encodes a Vix image or raw bytes as AVIF.

  Defaults to libvips' `effort: 4` — a good balance between encode speed and
  file size. Larger effort values compress further but get much slower.
  """
  @spec to_avif!(Vix.Vips.Image.t() | binary(), keyword()) :: binary()
  def to_avif!(image_or_bytes, opts \\ [])

  def to_avif!(%Vix.Vips.Image{} = image, opts) do
    effort = Keyword.get(opts, :effort, 4)
    Image.write!(image, :memory, suffix: ".avif", effort: effort)
  end

  def to_avif!(bytes, opts) when is_binary(bytes) do
    bytes |> to_image!() |> to_avif!(opts)
  end

  @doc """
  Resizes the image to a thumbnail and encodes it as AVIF.
  """
  @spec to_thumbnail_avif!(Vix.Vips.Image.t() | binary(), pos_integer()) :: binary()
  def to_thumbnail_avif!(image_or_bytes, length \\ 300)

  def to_thumbnail_avif!(%Vix.Vips.Image{} = image, length) do
    image |> Image.thumbnail!(length) |> to_avif!()
  end

  def to_thumbnail_avif!(bytes, length) when is_binary(bytes) do
    bytes |> to_image!() |> to_thumbnail_avif!(length)
  end

  def crop!("data:image/" <> _ = dataurl, x, y, w, h) do
    dataurl
    |> to_image!()
    |> crop!(x, y, w, h)
  end

  def crop!(%Vix.Vips.Image{} = image, x, y, w, h) do
    Image.crop!(image, x, y, w, h)
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

  @doc """
  Writes a stored image attribute to a file for inspection.

  Handles both the new binary columns (`:raw_data`, `:processed_data`,
  `:thumbnail`) and the legacy data-URL columns (`:raw`, `:processed`).
  """
  def write_image_from_db(id, attribute \\ :processed_data) do
    sketch = Ash.get!(Sketch, id)
    bytes = sketch |> Map.get(attribute) |> to_bytes!()
    ext = extension_for(attribute)
    filename = "#{id}-#{attribute}.#{ext}"
    File.write!(filename, bytes)
    IO.puts("Image has been written to #{filename}")
  end

  defp to_bytes!(bytes) when is_binary(bytes) do
    case bytes do
      "data:image/" <> _ -> decode_dataurl!(bytes)
      _ -> bytes
    end
  end

  defp extension_for(:raw_data), do: "jpg"
  defp extension_for(:raw), do: "jpg"
  defp extension_for(:processed_data), do: "avif"
  defp extension_for(:thumbnail), do: "avif"
  defp extension_for(:processed), do: "webp"

  def recent_sketches(count) do
    Sketch
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(state == :succeeded)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(count)
    |> Ash.read!()
  end

  def inter_image_distances(images) do
    images
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] ->
      # Use RMSE comparison (same as in app_live.ex)
      case Image.compare(a, b, metric: :rmse) do
        {:ok, difference, _diff_image} ->
          # Convert to percentage scale (0-100)
          difference * 100

        {:error, _reason} ->
          # Fallback to hamming distance
          {:ok, d} = Image.hamming_distance(a, b)
          d
      end
    end)
  end
end
