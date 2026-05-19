defmodule ImaginativeRestorationWeb.ReplicateWebhookController do
  @moduledoc """
  Receives Replicate prediction-completion webhooks and hands them to the
  shared `Sketches.Advance` dispatch, which drives the state machine forward
  (and applies the same retry-or-fail logic as the reconciler).
  """
  use ImaginativeRestorationWeb, :controller

  alias ImaginativeRestoration.AI.Replicate
  alias ImaginativeRestoration.Sketches.Advance
  alias ImaginativeRestoration.Sketches.Sketch

  require Logger

  def replicate(conn, %{"sketch_id" => sketch_id} = params) do
    case verify_signature(conn) do
      :ok ->
        case Ash.get(Sketch, String.to_integer(sketch_id)) do
          {:ok, sketch} ->
            Advance.advance(sketch, params)
            send_resp(conn, 200, "")

          {:error, _} = err ->
            Logger.warning("Webhook for unknown sketch #{sketch_id}: #{inspect(err)}")
            send_resp(conn, 200, "")
        end

      {:error, reason} ->
        Logger.warning("Rejected Replicate webhook for sketch #{sketch_id}: #{inspect(reason)}")
        send_resp(conn, 401, "")
    end
  rescue
    e ->
      Logger.error("Error handling Replicate webhook: #{Exception.message(e)}")
      send_resp(conn, 500, "")
  end

  defp verify_signature(conn) do
    case System.get_env("REPLICATE_WEBHOOK_SECRET") do
      nil ->
        Logger.warning("REPLICATE_WEBHOOK_SECRET not set; skipping webhook signature verification")
        :ok

      secret ->
        with [webhook_id] <- get_req_header(conn, "webhook-id"),
             [webhook_timestamp] <- get_req_header(conn, "webhook-timestamp"),
             [signature_header] <- get_req_header(conn, "webhook-signature"),
             raw_body when is_binary(raw_body) <- conn.assigns[:raw_body] do
          Replicate.verify_signature(raw_body, webhook_id, webhook_timestamp, signature_header, secret)
        else
          _ -> {:error, :missing_signature_headers}
        end
    end
  end
end
