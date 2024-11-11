defmodule ImaginativeRestoration.Sketches.Prompt do
  @moduledoc false
  use Ash.Resource,
    domain: ImaginativeRestoration.Sketches,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "prompts"
    repo ImaginativeRestoration.Repo
  end

  attributes do
    integer_primary_key :id

    # the prompt template: needs to include the substring "LABEL" which will
    # be replaced with the detected label from florence-2
    attribute :template, :string, allow_nil?: false

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read]

    read :latest do
      get? true

      prepare fn query, _context ->
        query
        |> Ash.Query.sort(updated_at: :desc)
        |> Ash.Query.limit(1)
      end
    end

    create :create do
      accept [:template]
      validate match(:template, ~r/LABEL/)
    end
  end
end
