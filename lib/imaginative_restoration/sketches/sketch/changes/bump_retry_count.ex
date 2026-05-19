defmodule ImaginativeRestoration.Sketches.Sketch.Changes.BumpRetryCount do
  @moduledoc """
  Increments the sketch's `:retry_count` and clears any prior error. Used by the
  `:retry_generation` and `:retry_bg_removal` actions when a provider-side
  failure is retried.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    current = changeset.data.retry_count || 0

    changeset
    |> Ash.Changeset.force_change_attribute(:retry_count, current + 1)
    |> Ash.Changeset.force_change_attribute(:error, nil)
  end
end
