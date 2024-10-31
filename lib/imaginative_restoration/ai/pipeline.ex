defmodule ImaginativeRestoration.AI.Pipeline do
  @moduledoc false
  use Ash.Resource.Change

  alias ImaginativeRestoration.AI.Replicate
  alias ImaginativeRestoration.AI.Utils

  @impl true
  def init(opts) do
    stage = Keyword.get(opts, :stage)

    if stage in [:crop_and_set_prompt, :process] do
      {:ok, opts}
    else
      {:error, "stage must be either :crop_and_set_prompt or :process"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    case Keyword.fetch!(opts, :stage) do
      :crop_and_set_prompt ->
        raw = changeset.data.raw

        case Replicate.invoke("lucataco/florence-2-large", raw) do
          {:ok, {label, [x, y, w, h]}} ->
            prompt =
              "beautiful multicolored scientific illustration of a lone #{label}, isolated against a plain white background, vivid detail"

            cropped = raw |> Utils.crop!(x, y, w, h) |> Utils.to_dataurl!()

            changeset
            |> Ash.Changeset.force_change_attribute(:label, label)
            |> Ash.Changeset.force_change_attribute(:prompt, prompt)
            |> Ash.Changeset.force_change_attribute(:cropped, cropped)

          _ ->
            changeset
        end

      :process ->
        cropped = changeset.data.cropped
        model = changeset.data.model
        prompt = changeset.data.prompt

        with {:ok, ai_image} <- Replicate.invoke(model, cropped, prompt),
             {:ok, final_image_url} <- Replicate.invoke("lucataco/remove-bg", ai_image) do
          final_image_dataurl = Utils.to_dataurl!(final_image_url)

          Ash.Changeset.force_change_attribute(changeset, :processed, final_image_dataurl)
        end
    end
  end
end
