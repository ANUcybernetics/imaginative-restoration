defmodule ImaginativeRestoration.Changes.Process do
  @moduledoc false
  use Ash.Resource.Change

  alias ImaginativeRestoration.AI.Replicate

  @impl true
  def change(changeset, _opts, _context) do
    unprocessed = changeset.data.unprocessed
    model = changeset.data.model

    with {:ok, labels} <- Replicate.invoke("lucataco/florence-2-large", unprocessed),
         prompt =
           "1950s scientific illustration of a lone #{List.first(labels)}, isolated against a plain white background",
         {:ok, ai_image} <- Replicate.invoke(model, unprocessed, prompt),
         {:ok, final_image} <- Replicate.invoke("lucataco/remove-bg", ai_image) do
      changeset
      |> Ash.Changeset.force_change_attribute(:prompt, prompt)
      |> Ash.Changeset.force_change_attribute(:processed, final_image)
    else
      _ ->
        changeset
    end
  end
end
