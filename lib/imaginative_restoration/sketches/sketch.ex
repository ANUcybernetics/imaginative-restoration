defmodule ImaginativeRestoration.Sketches.Sketch do
  @moduledoc false
  use Ash.Resource,
    domain: ImaginativeRestoration.Sketches,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "sketches"
    repo ImaginativeRestoration.Repo
  end

  attributes do
    integer_primary_key :id

    # these are all image data URLs (webp)
    attribute :raw, :string, allow_nil?: false
    attribute :cropped, :string
    attribute :processed, :string

    # prompt will be calculated based on the image number & the object detected in the sketch
    # but useful to store it in the resource for later analysis
    attribute :prompt, :string

    # model is the model used to process the sketch
    # currently supported models are:
    #
    # - adirik/t2i-adapter-sdxl-sketch
    # - adirik/t2i-adapter-sdxl-canny
    # - adirik/t2i-adapter-sdxl-lineart
    # - philz1337x/controlnet-deliberate
    #
    attribute :model, :string, allow_nil?: false

    # should be set to true if the sketch doesn't show up on the canvas
    attribute :hidden, :boolean, default: false

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read]

    create :init do
      accept [:raw]

      # default model, for now
      change set_attribute(:model, "adirik/t2i-adapter-sdxl-sketch")
    end

    update :process do
      # No attributes needed - will process the sketch's existing raw image

      # Validate that we have an raw image to work with
      validate fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :raw) do
          nil -> {:error, raw: "cannot process without an raw image"}
          _ -> :ok
        end
      end

      change ImaginativeRestoration.Changes.Process
    end
  end
end
