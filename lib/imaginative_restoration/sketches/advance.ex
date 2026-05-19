defmodule ImaginativeRestoration.Sketches.Advance do
  @moduledoc """
  Drives a sketch's state machine from a Replicate prediction payload.

  Shared by the webhook controller (which receives the payload pushed from
  Replicate) and the `Sweeper` reconciler (which polls the Replicate API for
  predictions whose webhook never arrived). One code path means both routes
  apply the same retry-or-fail logic.

  ## Dispatch table

      payload status | sketch state          | outcome
      ---------------+-----------------------+----------------------------------
      succeeded      | :generating           | complete_generation
      succeeded      | :removing_background  | complete (download + thumbnail)
      failed/cancel  | :generating           | retry_generation OR fail
      failed/cancel  | :removing_background  | retry_bg_removal OR fail
      processing/... | any                   | :still_running (no DB write)

  Retry-or-fail is decided by `Sketch.max_retries/0`: under the cap → retry
  with a fresh prediction (and new random prompt for generation); at the cap
  → transition to `:failed`.
  """

  alias ImaginativeRestoration.AI.Replicate
  alias ImaginativeRestoration.Sketches
  alias ImaginativeRestoration.Sketches.Sketch
  alias ImaginativeRestoration.Utils

  require Logger

  @bg_removal_model "851-labs/background-remover"

  @typedoc "Result of advancing a sketch. `:still_running` means we made no DB change."
  @type result ::
          {:ok, :advanced | :retried | :failed | :still_running | :ignored}
          | {:error, any()}

  @doc """
  Advances `sketch` based on `payload` (a Replicate prediction body, either from
  a webhook or from `Replicate.get_prediction/1`). Returns one of:

    * `{:ok, :advanced}` — state moved forward (succeeded path)
    * `{:ok, :retried}`  — provider failure with retry budget; new prediction submitted
    * `{:ok, :failed}`   — provider failure, no retries left; transitioned to `:failed`
    * `{:ok, :still_running}` — Replicate still working; nothing to do
    * `{:ok, :ignored}`  — payload doesn't apply to this sketch's current state
    * `{:error, reason}` — something went wrong driving the transition
  """
  @spec advance(Sketch.t(), map()) :: result()
  def advance(%Sketch{} = sketch, %{"status" => status} = payload) when status in ["succeeded"] do
    handle_success(sketch, payload)
  end

  def advance(%Sketch{} = sketch, %{"status" => status} = payload) when status in ["failed", "canceled"] do
    handle_failure(sketch, payload, status)
  end

  def advance(%Sketch{} = sketch, %{"status" => status}) when status in ["starting", "processing"] do
    Logger.debug("Sketch #{sketch.id}: Replicate still #{status}; leaving alone")
    {:ok, :still_running}
  end

  def advance(%Sketch{} = sketch, payload) do
    Logger.warning("Sketch #{sketch.id}: unrecognised payload shape: #{inspect(payload)}")
    {:ok, :ignored}
  end

  defp handle_success(%Sketch{state: :generating} = sketch, payload) do
    case Replicate.extract_output(sketch.model, payload) do
      {:ok, output_url} ->
        case Sketches.complete_generation(sketch, output_url) do
          {:ok, _} -> {:ok, :advanced}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        handle_failure(sketch, %{"error" => inspect(reason)}, "failed")
    end
  end

  defp handle_success(%Sketch{state: :removing_background} = sketch, payload) do
    with {:ok, output_url} <- Replicate.extract_output(@bg_removal_model, payload),
         {:ok, image} <- safe_to_image(output_url),
         {:ok, processed_data} <- safe_to_avif(image),
         {:ok, thumbnail} <- safe_to_thumbnail(image) do
      case Sketches.complete(sketch, processed_data, thumbnail) do
        {:ok, _} -> {:ok, :advanced}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} -> handle_failure(sketch, %{"error" => inspect(reason)}, "failed")
    end
  end

  defp handle_success(%Sketch{state: state} = sketch, _payload) when state in [:succeeded, :failed] do
    Logger.debug("Sketch #{sketch.id}: success payload arrived but already in #{state}; ignoring")
    {:ok, :ignored}
  end

  defp handle_success(%Sketch{state: state} = sketch, _payload) do
    Logger.warning("Sketch #{sketch.id}: success payload for unexpected state #{state}")
    {:ok, :ignored}
  end

  defp handle_failure(%Sketch{state: state} = sketch, payload, status) when state in [:generating, :removing_background] do
    error_text = error_message(payload, status)
    max = Sketch.max_retries()

    if status != "canceled" and sketch.retry_count < max do
      retry(sketch, state, error_text)
    else
      case Sketches.fail(sketch, error_text) do
        {:ok, _} -> {:ok, :failed}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp handle_failure(%Sketch{state: state} = sketch, _payload, _status) when state in [:succeeded, :failed] do
    Logger.debug("Sketch #{sketch.id}: failure payload arrived but already in #{state}; ignoring")
    {:ok, :ignored}
  end

  defp handle_failure(%Sketch{} = sketch, _payload, _status) do
    Logger.warning("Sketch #{sketch.id}: failure payload for unexpected state #{sketch.state}")
    {:ok, :ignored}
  end

  defp retry(%Sketch{state: :generating} = sketch, _state, error_text) do
    Logger.info(
      "Sketch #{sketch.id}: retry_generation (attempt #{sketch.retry_count + 1}/#{Sketch.max_retries()}) after: #{error_text}"
    )

    case Sketches.retry_generation(sketch) do
      {:ok, _} -> {:ok, :retried}
      {:error, reason} -> {:error, reason}
    end
  end

  defp retry(%Sketch{state: :removing_background} = sketch, _state, error_text) do
    Logger.info(
      "Sketch #{sketch.id}: retry_bg_removal (attempt #{sketch.retry_count + 1}/#{Sketch.max_retries()}) after: #{error_text}"
    )

    case Sketches.retry_bg_removal(sketch) do
      {:ok, _} -> {:ok, :retried}
      {:error, reason} -> {:error, reason}
    end
  end

  defp error_message(%{"error" => err}, _status) when is_binary(err) and err != "", do: err
  defp error_message(_payload, status), do: "Prediction #{status}"

  defp safe_to_image(url) do
    {:ok, Utils.to_image!(url)}
  rescue
    e -> {:error, "to_image failed: #{Exception.message(e)}"}
  end

  defp safe_to_avif(image) do
    {:ok, Utils.to_avif!(image)}
  rescue
    e -> {:error, "to_avif failed: #{Exception.message(e)}"}
  end

  defp safe_to_thumbnail(image) do
    {:ok, Utils.to_thumbnail_avif!(image)}
  rescue
    e -> {:error, "to_thumbnail failed: #{Exception.message(e)}"}
  end
end
