defmodule ImaginativeRestoration.Sketches.Sketch do
  @moduledoc """
  Represents a sketch and its lifecycle through the AI processing pipeline.

  ## States

      :created --submit_generation--> :generating
                                          |
                                          +--complete_generation--> :removing_background
                                          |                              |
                                          |                              +--complete--> :succeeded
                                          |                              |
                                          +--fail---------+              +--fail--> :failed
                                                          v
                                                       :failed
  """
  use Ash.Resource,
    domain: ImaginativeRestoration.Sketches,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshStateMachine],
    notifiers: [Ash.Notifier.PubSub]

  alias ImaginativeRestoration.AI.Pipeline

  sqlite do
    table "sketches"
    repo ImaginativeRestoration.Repo
  end

  state_machine do
    initial_states([:created])
    default_initial_state(:created)

    transitions do
      transition(:submit_generation, from: :created, to: :generating)
      transition(:complete_generation, from: :generating, to: :removing_background)
      transition(:complete, from: :removing_background, to: :succeeded)
      transition(:fail, from: [:created, :generating, :removing_background], to: :failed)
    end
  end

  attributes do
    integer_primary_key :id

    attribute :raw, :string, allow_nil?: false
    attribute :processed, :string
    attribute :intermediate_image, :string
    attribute :prompt, :string
    attribute :model, :string, allow_nil?: false
    attribute :prediction_id, :string
    attribute :error, :string
    attribute :hidden, :boolean, default: false

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :init do
      accept [:raw]
      argument :model, :string, default: "black-forest-labs/flux-canny-dev"

      change ImaginativeRestoration.Sketches.Sketch.Changes.SetModelOrDefault
    end

    update :submit_generation do
      validate present(:raw), message: "cannot process without a raw image"
      require_atomic? false

      change {Pipeline, stage: :submit_generation}
      change transition_state(:generating)
    end

    update :complete_generation do
      accept [:intermediate_image]
      require_atomic? false

      change {Pipeline, stage: :submit_bg_removal}
      change transition_state(:removing_background)
    end

    update :complete do
      accept [:processed]
      require_atomic? false

      change transition_state(:succeeded)
    end

    update :fail do
      accept [:error]
      require_atomic? false

      change transition_state(:failed)
    end
  end

  pub_sub do
    module ImaginativeRestorationWeb.Endpoint
    prefix "sketch"
    publish_all :create, "updated"
    publish_all :update, "updated"
  end
end
