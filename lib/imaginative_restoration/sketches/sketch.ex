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

    custom_indexes do
      index [:inserted_at]
    end
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

    attribute :raw_data, :binary
    attribute :processed_data, :binary
    attribute :thumbnail, :binary
    # `:raw` is the legacy text data-URL column, kept NOT NULL at the DB
    # level because SQLite can't drop the constraint in place. New rows get
    # an empty placeholder via the default; the column will be removed in a
    # follow-up migration after backfill.
    attribute :raw, :string,
      allow_nil?: false,
      default: "",
      constraints: [allow_empty?: true, trim?: false]

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
      accept [:raw_data]
      argument :model, :string, default: "black-forest-labs/flux-canny-dev"

      validate present(:raw_data), message: "cannot create without a raw image"

      change ImaginativeRestoration.Sketches.Sketch.Changes.SetModelOrDefault
    end

    update :submit_generation do
      validate present(:raw_data), message: "cannot process without a raw image"
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
      accept [:processed_data, :thumbnail]
      require_atomic? false

      change transition_state(:succeeded)
    end

    update :fail do
      accept [:error]
      require_atomic? false

      change transition_state(:failed)
    end

    update :backfill_images do
      accept [:raw_data, :processed_data, :thumbnail]
      require_atomic? false
    end
  end

  pub_sub do
    module ImaginativeRestorationWeb.Endpoint
    prefix "sketch"
    publish_all :create, "updated"
    publish_all :update, "updated"
  end

  alias ImaginativeRestoration.Utils

  @doc """
  Returns a data URL suitable for an `<img src=>`, preferring the smallest
  cached representation available (thumbnail → processed → raw). Legacy
  data-URL text columns are returned as-is.
  """
  def display_url(nil), do: nil
  def display_url(%{thumbnail: t}) when is_binary(t), do: Utils.encode_dataurl(t, :avif)
  def display_url(%{processed_data: p}) when is_binary(p), do: Utils.encode_dataurl(p, :avif)
  def display_url(%{processed: p}) when is_binary(p), do: p
  def display_url(%{raw_data: r}) when is_binary(r), do: Utils.encode_dataurl(r, :jpeg)
  def display_url(%{raw: r}) when is_binary(r), do: r
  def display_url(_), do: nil

  @doc """
  Like `display_url/1` but only returns the full-resolution processed image,
  skipping the thumbnail. Used by the admin view for side-by-side previews.
  """
  def processed_url(nil), do: nil
  def processed_url(%{processed_data: p}) when is_binary(p), do: Utils.encode_dataurl(p, :avif)
  def processed_url(%{processed: p}) when is_binary(p), do: p
  def processed_url(_), do: nil

  @doc """
  Returns the raw input image as a data URL. Used by the admin "Input" column
  and by the Pipeline when submitting to Replicate.
  """
  def raw_url(nil), do: nil
  def raw_url(%{raw_data: r}) when is_binary(r), do: Utils.encode_dataurl(r, :jpeg)
  def raw_url(%{raw: r}) when is_binary(r), do: r
  def raw_url(_), do: nil
end
