defmodule ImaginativeRestoration.AI.Replicate do
  @moduledoc """
  Module for interacting with the Replicate API.
  """

  @base_url "https://api.replicate.com/v1"

  defp auth_token do
    System.get_env("REPLICATE_API_TOKEN")
  end

  @doc """
  Returns the latest version of the specified model.
  For official models, returns the model name itself as they don't have versions.
  """
  @spec get_latest_version(String.t()) :: {:ok, String.t()} | {:error, any()}
  def get_latest_version(model) do
    if is_official_model?(model) do
      {:ok, model}
    else
      url = "#{@base_url}/models/#{model}/versions"

      case Req.get(url, auth: {:bearer, auth_token()}) do
        {:ok, %{status: 200, body: body}} ->
          latest_version = body["results"] |> List.first() |> Map.get("id")
          {:ok, latest_version}

        {:ok, %{status: status, body: body}} ->
          {:error, "HTTP #{status}: #{inspect(body)}"}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp is_official_model?(model) do
    String.starts_with?(model, "black-forest-labs/")
  end

  @doc """
  Creates a prediction using the specified model version and input.
  For official models, uses a different API endpoint.
  """
  @spec create_prediction(String.t(), map()) :: {:ok, map()} | {:error, any()}
  def create_prediction(model_or_version, input) do
    {url, body} =
      if is_official_model?(model_or_version) do
        # Official models use /models/{owner}/{name}/predictions endpoint
        {"#{@base_url}/models/#{model_or_version}/predictions", %{input: input}}
      else
        # Regular models use /predictions endpoint with version
        {"#{@base_url}/predictions", %{version: model_or_version, input: input}}
      end

    case Req.post(url, json: body, auth: {:bearer, auth_token()}) do
      {:ok, %{status: 201, body: body}} ->
        poll_prediction(body["id"])

      {:ok, %{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, error} ->
        {:error, error}
    end
  end

  defp poll_prediction(prediction_id) do
    url = "#{@base_url}/predictions/#{prediction_id}"

    case Req.get(url, auth: {:bearer, auth_token()}) do
      {:ok, %{status: 200, body: %{"status" => status} = body}} ->
        case status do
          "succeeded" ->
            {:ok, body}

          "failed" ->
            {:error, body["error"] || "Prediction failed"}

          "canceled" ->
            {:error, "Prediction was canceled"}

          _ ->
            # Wait for 1 second before polling again
            Process.sleep(1000)
            poll_prediction(prediction_id)
        end

      {:ok, %{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Cancels a running prediction.
  """
  @spec cancel_prediction(String.t()) :: {:ok, map()} | {:error, any()}
  def cancel_prediction(prediction_id) do
    url = "#{@base_url}/predictions/#{prediction_id}/cancel"

    case Req.post(url, auth: {:bearer, auth_token()}) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, error} ->
        {:error, error}
    end
  end

  ## here are the model-specific invocations (no need to have a separate module, just pattern match on the model name)
  def invoke("adirik/t2i-adapter-sdxl" <> _ = model, input_image, prompt) do
    input = %{
      image: input_image,
      prompt: prompt,
      negative_prompt: "extra digit, fewer digits, cropped, worst quality, low quality",
      adapter_conditioning_scale: 0.65,
      num_inference_steps: 10,
      # 32-bit INT_MAX
      random_seed: :rand.uniform(2_147_483_647)
    }

    with {:ok, version} <- get_latest_version(model),
         {:ok, %{"output" => [_canny, output]}} <- create_prediction(version, input) do
      {:ok, output}
    end
  end

  def invoke("philz1337x/controlnet-deliberate" = model, input_image, prompt) do
    input = %{
      image: input_image,
      prompt: prompt,
      weight: 1,
      low_threshold: 1,
      high_threshold: 5,
      detect_resolution: 128
    }

    with {:ok, version} <- get_latest_version(model),
         {:ok, %{"output" => [_canny, output]}} <- create_prediction(version, input) do
      {:ok, output}
    end
  end

  ## here are the model-specific invocations (no need to have a separate module, just pattern match on the model name)
  def invoke("xlabs-ai/flux-dev-controlnet" = model, input_image, prompt) do
    input = %{
      prompt: prompt,
      control_image: input_image,
      steps: 10,
      control_type: "canny",
      control_strength: 0.5,
      image_to_image_strength: 0.1,
      guidance_scale: 0.25
    }

    with {:ok, version} <- get_latest_version(model),
         {:ok, %{"output" => [output]}} <- create_prediction(version, input) do
      {:ok, output}
    end
  end

  def invoke("black-forest-labs/flux-canny-dev" = model, input_image, prompt) do
    input = %{
      prompt: prompt,
      control_image: input_image,
      control_strength: 0.4,
      num_inference_steps: 28,
      guidance_scale: 3.5,
      seed: :rand.uniform(2_147_483_647)
    }

    with {:ok, version} <- get_latest_version(model),
         {:ok, %{"output" => [output]}} <- create_prediction(version, input) do
      {:ok, output}
    end
  end

  def invoke("lucataco/florence-2-large" = model, input_image) do
    input = %{
      image: input_image,
      task_input: "Object Detection"
    }

    with {:ok, version} <- get_latest_version(model),
         {:ok, %{"output" => %{"text" => bad_json}}} <- create_prediction(version, input) do
      body =
        bad_json
        # some pre-processing required because this model returns invalid json
        |> String.replace("'", "\"")
        |> Jason.decode!()
        |> Map.fetch!("<OD>")

      # zip the bounding boxes and labels together
      objects =
        body["labels"]
        |> Enum.zip(body["bboxes"])
        # use the x, y, width, height format
        |> Enum.map(fn {label, [x1, y1, x2, y2]} -> {label, Enum.map([x1, y1, x2 - x1, y2 - y1], &round/1)} end)
        |> Enum.reject(fn {label, _} -> label in ["envelope", "whiteboard"] end)
        # sort by height (tallest first)
        |> Enum.sort_by(fn {_, [_, _, _, h]} -> h end, :desc)

      if objects == [] do
        {:error, :no_valid_label}
      else
        {:ok, List.first(objects)}
      end
    end
  end

  def invoke("lucataco/remove-bg" = model, input_image) do
    input = %{image: input_image}

    with {:ok, version} <- get_latest_version(model),
         {:ok, %{"output" => output}} <- create_prediction(version, input) do
      {:ok, output}
    end
  end

  def invoke("851-labs/background-remover" = model, input_image) do
    input = %{image: input_image}

    with {:ok, version} <- get_latest_version(model),
         {:ok, %{"output" => output}} <- create_prediction(version, input) do
      {:ok, output}
    end
  end
end
