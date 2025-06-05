defmodule ImaginativeRestoration.Sketches.Sketch do
  @moduledoc """
  Represents a sketch that can be processed through AI models.
  """
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

    # Raw sketch image data URL (webp)
    attribute :raw, :string, allow_nil?: false

    # Processed AI-generated image data URL (webp)
    attribute :processed, :string

    # The prompt used to generate the processed image
    attribute :prompt, :string

    # Model used to process the sketch (e.g., "black-forest-labs/flux-canny-dev")
    attribute :model, :string, allow_nil?: false

    # Should be set to true if the sketch doesn't show up on the canvas
    attribute :hidden, :boolean, default: false

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read]

    create :init do
      accept [:raw]
      argument :model, :string, default: "black-forest-labs/flux-canny-dev"

      change fn changeset, _context ->
        model_arg = Ash.Changeset.get_argument(changeset, :model)

        actual_model =
          case model_arg do
            # Default if empty string is passed
            "" -> "black-forest-labs/flux-canny-dev"
            # Default if nil is passed (should be caught by arg default if not provided)
            nil -> "black-forest-labs/flux-canny-dev"
            _ -> model_arg
          end

        Ash.Changeset.force_change_attribute(changeset, :model, actual_model)
      end
    end

    update :process do
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
