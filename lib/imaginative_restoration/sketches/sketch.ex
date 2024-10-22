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
    attribute :prompt, :string, allow_nil?: false
    attribute :unprocessed, :string, allow_nil?: false
    attribute :processed, :string
    attribute :model, :string, allow_nil?: false
    attribute :hidden, :boolean, default: false

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
