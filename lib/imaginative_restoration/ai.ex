defmodule ImaginativeRestoration.AI do
  @moduledoc false

  alias ImaginativeRestoration.AI.Replicate

  def sketch2img(input_image, prompt) do
    Replicate.invoke("adirik/t2i-adapter-sdxl-sketch", input_image, prompt)
  end

  def detect_objects(input_image) do
    Replicate.invoke("lucataco/florence-2-large", input_image)
  end

  def remove_bg(input_image) do
    Replicate.invoke("lucataco/remove-bg", input_image)
  end

  def process(input_image) do
    with {:ok, labels} <- detect_objects(input_image),
         prompt = Enum.join(labels, ", ") <> "in the style of fauvism, matisse",
         {:ok, ai_image} <- sketch2img(input_image, prompt) do
      remove_bg(ai_image)
    end
  end
end
