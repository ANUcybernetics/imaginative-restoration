defmodule ImaginativeRestoration.AI.Pipeline do
  @moduledoc """
  Submits Replicate predictions for the two pipeline stages.

  Each stage is a fire-and-forget submission: the prediction's `id` is captured
  onto the sketch as `:prediction_id`, and Replicate calls back via webhook when
  the prediction completes. The webhook controller then drives the next state
  transition.
  """
  use Ash.Resource.Change

  alias Ash.Changeset
  alias ImaginativeRestoration.AI.Replicate
  alias ImaginativeRestoration.Sketches.Prompt

  @impl true
  def init(opts) do
    stage = Keyword.get(opts, :stage)

    if stage in [:submit_generation, :submit_bg_removal] do
      {:ok, opts}
    else
      {:error, "stage must be :submit_generation or :submit_bg_removal"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    Changeset.before_action(changeset, fn cs ->
      submit(cs, Keyword.fetch!(opts, :stage))
    end)
  end

  defp submit(changeset, :submit_generation) do
    sketch = changeset.data
    prompt = Prompt.random_prompt()

    case Replicate.submit(sketch.model, sketch.raw, prompt: prompt, webhook_url: webhook_url(sketch)) do
      {:ok, prediction_id} ->
        changeset
        |> Changeset.force_change_attribute(:prediction_id, prediction_id)
        |> Changeset.force_change_attribute(:prompt, prompt)

      {:error, reason} ->
        Changeset.add_error(changeset, field: :prediction_id, message: "submission failed: #{inspect(reason)}")
    end
  end

  defp submit(changeset, :submit_bg_removal) do
    sketch = changeset.data
    intermediate_image = Changeset.get_attribute(changeset, :intermediate_image)

    case Replicate.submit("851-labs/background-remover", intermediate_image,
           prompt: nil,
           webhook_url: webhook_url(sketch)
         ) do
      {:ok, prediction_id} ->
        Changeset.force_change_attribute(changeset, :prediction_id, prediction_id)

      {:error, reason} ->
        Changeset.add_error(changeset, field: :prediction_id, message: "submission failed: #{inspect(reason)}")
    end
  end

  defp webhook_url(sketch) do
    base = Application.fetch_env!(:imaginative_restoration, :webhook_base_url)
    "#{base}/webhooks/replicate/#{sketch.id}"
  end
end
