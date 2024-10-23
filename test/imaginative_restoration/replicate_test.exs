defmodule ImaginativeRestoration.ReplicateTest do
  use ImaginativeRestoration.DataCase

  alias ImaginativeRestoration.AI.Replicate

  defp invoke_args do
    sketch_image = "https://fly.storage.tigris.dev/imaginative-restoration-sketches/butterfly-sketch.png"
    processed_image = "https://fly.storage.tigris.dev/imaginative-restoration-sketches/butterfly-matisse.png"
    prompt = "fauvism, matisse, cave painting"

    [
      ["adirik/t2i-adapter-sdxl-sketch", sketch_image, prompt],
      ["lucataco/florence-2-large", sketch_image],
      ["lucataco/remove-bg", processed_image]
    ]
  end

  describe "Replicate platform" do
    @describetag timeout: :timer.minutes(10)

    test "can list latest model version for all models" do
      for [model | _] <- invoke_args() do
        assert {:ok, version} = Replicate.get_latest_version(model)
        assert String.match?(version, ~r/^[a-f0-9]{64}$/)
      end
    end

    # @tag skip: true
    test "can successfully invoke all Replicate models" do
      tasks =
        for [model | _] = args <- invoke_args() do
          IO.puts("invoking #{model}...")

          Task.async(fn ->
            result = apply(Replicate, :invoke, args)

            case result do
              {:ok, output} ->
                IO.puts("#{model} output: #{output}")

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
  end
end
