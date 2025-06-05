defmodule ImaginativeRestoration.Sketches.Sketch do
  @moduledoc false
  use Ash.Resource,
    domain: ImaginativeRestoration.Sketches,
    data_layer: AshSqlite.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  alias ImaginativeRestoration.AI.Pipeline

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
    attribute :label, :string
    attribute :prompt, :string

    # model is the model used to process the sketch (a user/model replicate path)
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
      argument :model, :string, default: "black-forest-labs/flux-canny-dev"

      # default model, updated to use flux-canny-dev
      change set_attribute(:model, arg(:model))
    end

    update :crop_and_label do
      # No attributes needed - will process the sketch's existing raw image

      # Validate that we have an raw image to work with
      validate present(:raw), message: "cannot crop without an raw image"

      change {Pipeline, stage: :crop_and_label}
    end

    update :process do
      # No attributes needed - will process the sketch's existing cropped image
      validate present(:raw), message: "cannot process without a raw image"

      change {Pipeline, stage: :process}
    end
  end

  pub_sub do
    module ImaginativeRestorationWeb.Endpoint
    prefix "sketch"
    publish_all :create, "updated"
    publish_all :update, "updated"
  end
end
