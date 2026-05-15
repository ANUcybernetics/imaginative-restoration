defmodule ImaginativeRestoration.Sketches do
  @moduledoc """
  Domain for managing sketches and their AI processing pipeline.
  """
  use Ash.Domain

  alias ImaginativeRestoration.Sketches.Sketch

  resources do
    resource Sketch do
      define :init, args: [:raw]
      define :init_with_model, args: [:raw, :model], action: :init
      define :submit_generation
      define :complete_generation, args: [:intermediate_image]
      define :complete, args: [:processed]
      define :fail, args: [:error]
    end
  end
end
