defmodule ImaginativeRestoration.Sketches.Sketch.Changes.SetModelOrDefault do
  @moduledoc """
  Sets the `:model` attribute from the `:model` argument, falling back to the
  default model when the argument is `nil` or an empty string.
  """
  use Ash.Resource.Change

  @default_model "google/nano-banana"

  @impl true
  def change(changeset, _opts, _context) do
    model =
      case Ash.Changeset.get_argument(changeset, :model) do
        nil -> @default_model
        "" -> @default_model
        value -> value
      end

    Ash.Changeset.force_change_attribute(changeset, :model, model)
  end
end
