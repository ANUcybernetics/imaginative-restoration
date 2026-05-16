defmodule ImaginativeRestorationWeb.ReplicateWebhookController do
  @moduledoc """
  Receives Replicate prediction-completion webhooks and drives the sketch
  state machine forward.

  Dispatch is by the sketch's current state:
    * `:generating` → submit the bg-removal prediction (via `complete_generation`)
    * `:removing_background` → store the final image (via `complete`)

  Failures at any stage transition the sketch to `:failed`.
  """
  use ImaginativeRestorationWeb, :controller

  alias ImaginativeRestoration.AI.Replicate
  alias ImaginativeRestoration.Sketches
  alias ImaginativeRestoration.Sketches.Sketch
  alias ImaginativeRestoration.Utils

  require Logger

  @bg_removal_model "851-labs/background-remover"

  def replicate(conn, %{"sketch_id" => sketch_id} = params) do
    case verify_signature(conn) do
      :ok ->
        Sketch
        |> Ash.get(String.to_integer(sketch_id))
        |> handle(params)

        send_resp(conn, 200, "")

      {:error, reason} ->
        Logger.warning("Rejected Replicate webhook for sketch #{sketch_id}: #{inspect(reason)}")
        send_resp(conn, 401, "")
    end
  rescue
    e ->
      Logger.error("Error handling Replicate webhook: #{Exception.message(e)}")
      send_resp(conn, 500, "")
  end

  defp handle({:ok, %Sketch{state: :generating} = sketch}, %{"status" => "succeeded"} = payload) do
    case Replicate.extract_output(sketch.model, payload) do
      {:ok, output_url} -> Sketches.complete_generation(sketch, output_url)
      {:error, reason} -> Sketches.fail(sketch, inspect(reason))
    end
  end

  defp handle({:ok, %Sketch{state: :removing_background} = sketch}, %{"status" => "succeeded"} = payload) do
    case Replicate.extract_output(@bg_removal_model, payload) do
      {:ok, output_url} ->
        image = Utils.to_image!(output_url)
        processed_data = Utils.to_avif!(image)
        thumbnail = Utils.to_thumbnail_avif!(image)
        Sketches.complete(sketch, processed_data, thumbnail)

      {:error, reason} ->
        Sketches.fail(sketch, inspect(reason))
    end
  end

  defp handle({:ok, sketch}, %{"status" => status} = payload) when status in ["failed", "canceled"] do
    Sketches.fail(sketch, payload["error"] || "Prediction #{status}")
  end

  defp handle({:ok, sketch}, payload) do
    Logger.warning("Ignoring webhook for sketch #{sketch.id} in state #{sketch.state}: #{inspect(payload)}")
    :ok
  end

  defp handle({:error, _} = err, _payload) do
    Logger.warning("Webhook for unknown sketch: #{inspect(err)}")
    :ok
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
