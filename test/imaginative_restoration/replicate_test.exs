defmodule ImaginativeRestoration.ReplicateTest do
  use ImaginativeRestoration.DataCase

  alias ImaginativeRestoration.AI.Replicate
  alias ImaginativeRestoration.Utils

  defp invoke_args do
    sketch_image = "https://fly.storage.tigris.dev/imaginative-restoration-sketches/butterfly-sketch.png"
    processed_image = "https://fly.storage.tigris.dev/imaginative-restoration-sketches/butterfly-matisse.png"
    prompt = "fauvism, matisse, cave painting"

    [
      ["adirik/t2i-adapter-sdxl-sketch", sketch_image, prompt],
      ["adirik/t2i-adapter-sdxl-canny", sketch_image, prompt],
      ["adirik/t2i-adapter-sdxl-lineart", sketch_image, prompt],
      ["philz1337x/controlnet-deliberate", sketch_image, prompt],
      ["black-forest-labs/flux-canny-dev", sketch_image, prompt],
      ["lucataco/florence-2-large", sketch_image],
      ["lucataco/remove-bg", processed_image]
    ]
  end

  describe "Replicate platform" do
    @describetag timeout: to_timeout(minute: 10)

    test "can list latest model version for all models" do
      for [model | _] <- invoke_args() do
        assert {:ok, version} = Replicate.get_latest_version(model)

        # Official models return the model name, others return a 64-char hex version ID
        if String.starts_with?(model, "black-forest-labs/") do
          assert version == model
        else
          assert String.match?(version, ~r/^[a-f0-9]{64}$/)
        end
      end
    end

    # @tag skip: "makes real API calls"
    test "can successfully invoke all Replicate models" do
      tasks =
        for [model | _] = args <- invoke_args() do
          IO.puts("invoking #{model}...")

          Task.async(fn ->
            result = apply(Replicate, :invoke, args)

            case result do
              {:ok, output} ->
                IO.puts("#{model} output: #{inspect(output)}")

              _ ->
                :pass
            end

            {model, result}
          end)
        end

      results = Task.await_many(tasks, :infinity)

      failed_models =
        results
        |> Enum.filter(fn {_, result} ->
          case result do
            {:error, _} -> true
            _ -> false
          end
        end)
        |> Enum.map(fn {model, _} -> model end)

      if length(failed_models) > 0 do
        flunk("Failed models: #{Enum.join(failed_models, ", ")}")
      end
    end

    # @tag skip: "makes real API calls"
    test "can crop image to (Florence 2-provided) bounding box" do
      sketch_image_url = "https://fly.storage.tigris.dev/imaginative-restoration-sketches/shark-sketch.png"
      sketch_image = Utils.to_image!(sketch_image_url)

      cropped_image_path = "/tmp/cropped.webp"

      {:ok, {_label, [x, y, w, h]}} = Replicate.invoke("lucataco/florence-2-large", sketch_image_url)

      sketch_image
      |> Utils.crop!(x, y, w, h)
      |> Image.write!(cropped_image_path)
    end
  end
end
