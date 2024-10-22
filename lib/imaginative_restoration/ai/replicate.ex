defmodule ImaginativeRestoration.AI.Replicate do
  @moduledoc """
  Module for interacting with the Replicate API.
  """

  @base_url "https://api.replicate.com/v1"
  # nice big timeout in case of Replicate cold starts
  @timeout :timer.minutes(5)

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

  This uses the new "Prefer" header to make this a blocking request.
  """
  @spec create_prediction(String.t(), map()) :: {:ok, map()} | {:error, any()}
  def create_prediction(model_version, input) do
    url = "#{@base_url}/predictions"

    body = %{
      version: model_version,
      input: input
    }

    case Req.post(url,
           json: body,
           headers: [{"Prefer", "wait=60"}],
           auth: {:bearer, auth_token()},
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 201, body: body}} ->
        {:ok, body}

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
  def invoke("adirik/t2i-adapter-sdxl-sketch" = model, input_image, prompt) do
    input = %{
      image: input_image,
      prompt: prompt
    }

    with {:ok, version} <- get_latest_version(model),
         {:ok, %{"output" => [_canny, output]}} <- create_prediction(version, input) do
      output
    end
  end
end
