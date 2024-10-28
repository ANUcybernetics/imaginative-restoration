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
  """
  @spec get_latest_version(String.t()) :: {:ok, String.t()} | {:error, any()}
  def get_latest_version(model) do
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

  @doc """
  Creates a prediction using the specified model version and input.
  """
  @spec create_prediction(String.t(), map()) :: {:ok, map()} | {:error, any()}
  def create_prediction(model_version, input) do
    url = "#{@base_url}/predictions"

    body = %{
      version: model_version,
      input: input
    }

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
      negative_prompt:
        "extra digit, fewer digits, cropped, worst quality, low quality, glitch, deformed, mutated, ugly, disfigured, caption, signature, background illustration, poster",
      adapter_conditioning_scale: 0.7
    }

    with {:ok, version} <- get_latest_version(model),
         {:ok, %{"output" => [_canny, output]}} <- create_prediction(version, input) do
      {:ok, output}
    end
  end

  def invoke("philz1337x/controlnet-deliberate" = model, input_image, prompt) do
    input = %{
      image: input_image,
      prompt: prompt
    }

    with {:ok, version} <- get_latest_version(model),
         {:ok, %{"output" => [_canny, output]}} <- create_prediction(version, input) do
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

      label = List.first(body["labels"])
      [x1, y1, x2, y2] = body["bboxes"] |> List.first() |> Enum.map(&round/1)

      {:ok, {label, [x1, y1, x2 - x1, y2 - y1]}}
    end
  end

  def invoke("lucataco/remove-bg" = model, input_image) do
    input = %{image: input_image}

    with {:ok, version} <- get_latest_version(model),
         {:ok, %{"output" => output}} <- create_prediction(version, input) do
      {:ok, output}
    end
  end
end
