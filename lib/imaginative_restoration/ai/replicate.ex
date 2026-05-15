defmodule ImaginativeRestoration.AI.Replicate do
  @moduledoc """
  Client for the Replicate API.

  Predictions are submitted fire-and-forget with a webhook URL; Replicate calls
  back when the prediction completes. Use `submit/3` to kick off a prediction
  and `extract_output/2` to pull the final image URL out of the webhook payload.
  """

  @base_url "https://api.replicate.com/v1"

  defp auth_token, do: System.get_env("REPLICATE_API_TOKEN")

  @doc """
  Submits a prediction to Replicate with a webhook for completion.

  Returns `{:ok, prediction_id}` once the submission is accepted; the actual
  output arrives later via the webhook.

  Pass `prompt: nil` for models that don't take a text prompt (e.g. background
  removers).
  """
  @spec submit(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def submit(model, input_image, opts) do
    prompt = Keyword.get(opts, :prompt)
    webhook_url = Keyword.fetch!(opts, :webhook_url)
    input = build_input(model, input_image, prompt)

    with {:ok, version} <- get_latest_version(model),
         {:ok, %{"id" => prediction_id}} <- create_prediction(version, input, webhook_url) do
      {:ok, prediction_id}
    end
  end

  @doc """
  Extracts the final image URL from a completed prediction payload.

  Different models return their output in different shapes (some return a bare
  URL, some return `[canny_map, output]`, some return `[output]`); this knows
  which is which.
  """
  @spec extract_output(String.t(), map()) :: {:ok, String.t()} | {:error, any()}
  def extract_output(_model, %{"status" => "failed", "error" => error}), do: {:error, error || "Prediction failed"}
  def extract_output(_model, %{"status" => "canceled"}), do: {:error, "Prediction was canceled"}

  def extract_output("adirik/t2i-adapter-sdxl" <> _, %{"output" => [_canny, output]}), do: {:ok, output}
  def extract_output("philz1337x/controlnet-deliberate", %{"output" => [_canny, output]}), do: {:ok, output}
  def extract_output("xlabs-ai/flux-dev-controlnet", %{"output" => [output]}), do: {:ok, output}
  def extract_output("black-forest-labs/flux-canny-dev", %{"output" => [output]}), do: {:ok, output}
  def extract_output("lucataco/remove-bg", %{"output" => output}) when is_binary(output), do: {:ok, output}
  def extract_output("851-labs/background-remover", %{"output" => output}) when is_binary(output), do: {:ok, output}
  def extract_output(model, payload), do: {:error, "Unexpected output shape for #{model}: #{inspect(payload)}"}

  @doc """
  Verifies a Replicate webhook signature.

  Replicate uses Svix-style signatures: an HMAC-SHA256 of
  `<webhook-id>.<webhook-timestamp>.<body>` signed with the webhook secret.
  The header can contain multiple space-separated `v1,<sig>` entries; any match
  passes.
  """
  @spec verify_signature(String.t(), String.t(), String.t(), String.t(), String.t()) :: :ok | {:error, atom()}
  def verify_signature(body, webhook_id, webhook_timestamp, signature_header, secret) do
    signed_payload = "#{webhook_id}.#{webhook_timestamp}.#{body}"

    with {:ok, key} <- decode_secret(secret) do
      expected =
        :hmac
        |> :crypto.mac(:sha256, key, signed_payload)
        |> Base.encode64()

      signatures =
        signature_header
        |> String.split(" ", trim: true)
        |> Enum.map(fn entry ->
          case String.split(entry, ",", parts: 2) do
            ["v1", sig] -> sig
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      if Enum.any?(signatures, &Plug.Crypto.secure_compare(&1, expected)) do
        :ok
      else
        {:error, :invalid_signature}
      end
    end
  end

  defp decode_secret("whsec_" <> b64), do: Base.decode64(b64)
  defp decode_secret(other), do: {:ok, other}

  @doc """
  Returns the latest version of the specified model.

  Official Replicate models don't have versions; for those, returns the model
  name itself (the API uses a separate endpoint for them).
  """
  @spec get_latest_version(String.t()) :: {:ok, String.t()} | {:error, any()}
  def get_latest_version(model) do
    if official_model?(model) do
      {:ok, model}
    else
      cached_get_version(model)
    end
  end

  defp cached_get_version(model) do
    case :persistent_term.get({__MODULE__, :version, model}, nil) do
      nil ->
        with {:ok, version} <- fetch_latest_version(model) do
          :persistent_term.put({__MODULE__, :version, model}, version)
          {:ok, version}
        end

      version ->
        {:ok, version}
    end
  end

  defp fetch_latest_version(model) do
    url = "#{@base_url}/models/#{model}/versions"

    case Req.get(url, auth: {:bearer, auth_token()}) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body["results"] |> List.first() |> Map.get("id")}

      {:ok, %{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, error} ->
        {:error, error}
    end
  end

  defp official_model?(model), do: String.starts_with?(model, "black-forest-labs/")

  defp create_prediction(model_or_version, input, webhook_url) do
    {url, body} =
      if official_model?(model_or_version) do
        {"#{@base_url}/models/#{model_or_version}/predictions",
         %{input: input, webhook: webhook_url, webhook_events_filter: ["completed"]}}
      else
        {"#{@base_url}/predictions",
         %{version: model_or_version, input: input, webhook: webhook_url, webhook_events_filter: ["completed"]}}
      end

    case Req.post(url, json: body, auth: {:bearer, auth_token()}) do
      {:ok, %{status: 201, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, "HTTP #{status}: #{inspect(body)}"}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Cancels a running prediction. Used when a sketch is superseded before its
  prediction finishes.
  """
  @spec cancel_prediction(String.t()) :: {:ok, map()} | {:error, any()}
  def cancel_prediction(prediction_id) do
    url = "#{@base_url}/predictions/#{prediction_id}/cancel"

    case Req.post(url, auth: {:bearer, auth_token()}) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, "HTTP #{status}: #{inspect(body)}"}
      {:error, error} -> {:error, error}
    end
  end

  ## Model-specific input construction

  defp build_input("adirik/t2i-adapter-sdxl" <> _, image, prompt) do
    %{
      image: image,
      prompt: prompt,
      negative_prompt: "extra digit, fewer digits, cropped, worst quality, low quality",
      adapter_conditioning_scale: 0.65,
      num_inference_steps: 10,
      # 32-bit INT_MAX
      random_seed: :rand.uniform(2_147_483_647)
    }
  end

  defp build_input("philz1337x/controlnet-deliberate", image, prompt) do
    %{
      image: image,
      prompt: prompt,
      weight: 1,
      low_threshold: 1,
      high_threshold: 5,
      detect_resolution: 128
    }
  end

  defp build_input("xlabs-ai/flux-dev-controlnet", image, prompt) do
    %{
      prompt: prompt,
      control_image: image,
      steps: 10,
      control_type: "canny",
      control_strength: 0.5,
      image_to_image_strength: 0.1,
      guidance_scale: 0.25
    }
  end

  defp build_input("black-forest-labs/flux-canny-dev", image, prompt) do
    %{
      prompt: prompt,
      control_image: image,
      guidance: 10,
      num_inference_steps: 10,
      disable_safety_checker: true
    }
  end

  defp build_input("lucataco/remove-bg", image, _prompt), do: %{image: image}
  defp build_input("851-labs/background-remover", image, _prompt), do: %{image: image}
end
