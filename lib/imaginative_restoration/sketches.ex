defmodule ImaginativeRestoration.Sketches do
  @moduledoc """
  Domain for managing sketches and their AI processing pipeline.
  """
  use Ash.Domain

  alias ImaginativeRestoration.Sketches.Sketch

  resources do
    resource Sketch do
      define :init, args: [:raw_data]
      define :init_with_model, args: [:raw_data, :model], action: :init
      define :submit_generation
      define :complete_generation, args: [:intermediate_image]
      define :complete, args: [:processed_data, :thumbnail]
      define :retry_generation
      define :retry_bg_removal
      define :fail, args: [:error]
    end
  end
end
