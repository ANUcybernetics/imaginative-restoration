defmodule ImaginativeRestorationWeb.CacheBodyReader do
  @moduledoc """
  Body reader that stashes the raw request body in `conn.assigns[:raw_body]`
  before parsing. Required for webhook signature verification, where the
  signature is computed over the raw bytes (not the re-encoded JSON).
  """

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)

    conn =
      update_in(conn.assigns[:raw_body], fn
        nil -> body
        existing -> existing <> body
      end)

    {:ok, body, conn}
  end
end
