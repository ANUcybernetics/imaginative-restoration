defmodule ImaginativeRestoration.AI.Utils do
  @moduledoc false

  def download_to_webp_dataurl(url) do
    url
    |> Req.get!(stream: false)
    |> Map.get(:body)
    |> Image.open!()
    |> Image.write!(:memory, suffix: ".webp")
    |> Base.encode64()
    |> then(&("data:image/webp;base64," <> &1))
  end
end
