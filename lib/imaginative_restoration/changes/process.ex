defmodule ImaginativeRestoration.Changes.Process do
  @moduledoc false
  use Ash.Resource.Change

  alias ImaginativeRestoration.AI.Replicate
  alias ImaginativeRestoration.AI.Utils

  @impl true
  def change(changeset, _opts, _context) do
    raw = changeset.data.raw
    model = changeset.data.model

    with {:ok, labels} <- Replicate.invoke("lucataco/florence-2-large", raw),
         prompt =
           "1950s scientific illustration of a lone #{List.first(labels)}, isolated against a plain white background",
         {:ok, ai_image} <- Replicate.invoke(model, raw, prompt),
         {:ok, final_image_url} <- Replicate.invoke("lucataco/remove-bg", ai_image) do
      final_image_dataurl = Utils.download_to_webp_dataurl(final_image_url)

      changeset
      |> Ash.Changeset.force_change_attribute(:prompt, prompt)
      |> Ash.Changeset.force_change_attribute(:processed, final_image_dataurl)
    else
      _ ->
        changeset
    end
  end
end
