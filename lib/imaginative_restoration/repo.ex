defmodule ImaginativeRestoration.Repo do
  use AshSqlite.Repo, otp_app: :imaginative_restoration

  def min_sqlite_version do
    %Version{major: 3, minor: 53, patch: 4}
  end
end
