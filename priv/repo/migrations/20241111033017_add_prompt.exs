defmodule ImaginativeRestoration.Repo.Migrations.AddPrompt do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_sqlite.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:prompts, primary_key: false) do
      add :updated_at, :utc_datetime_usec, null: false
      add :inserted_at, :utc_datetime_usec, null: false
      add :template, :text, null: false
      add :id, :bigserial, null: false, primary_key: true
    end
  end

  def down do
    drop table(:prompts)
  end
end
