defmodule ImaginativeRestoration.ReplicateStubs do
  @moduledoc """
  Test helpers for stubbing Replicate HTTP responses via `Req.Test`.

  The Replicate client is configured (in `config/test.exs`) to route through
  `Req.Test`. Tests call the helpers here to register canned responses for
  specific request shapes — most commonly a GET on a prediction id and a POST
  that creates a new prediction.
  """

  @doc """
  Replies with HTTP 201 + JSON body. Use for `POST /predictions` responses,
  which Replicate uses to acknowledge prediction submission.
  """
  def json_created(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(201, Jason.encode!(body))
  end

  @doc """
  Pre-populates the `:persistent_term` cache that `Replicate.get_latest_version/1`
  reads from, so non-official models don't trigger an extra GET to
  `/models/.../versions` during tests.
  """
  def prime_version_cache do
    for model <- [
          "851-labs/background-remover",
          "lucataco/remove-bg",
          "men1scus/birefnet",
          "lucataco/sdxl-lightning-multi-controlnet",
          "adirik/t2i-adapter-sdxl-canny",
          "philz1337x/controlnet-deliberate",
          "xlabs-ai/flux-dev-controlnet"
        ] do
      :persistent_term.put({ImaginativeRestoration.AI.Replicate, :version, model}, "version_stub")
    end

    :ok
  end
end
