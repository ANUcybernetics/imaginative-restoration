defmodule ImaginativeRestoration.Sketches do
  @moduledoc """
  Domain for managing sketches and their AI processing pipeline.
  """
  use Ash.Domain, extensions: [AshAi]

  alias ImaginativeRestoration.Sketches.Sketch

  resources do
    resource Sketch do
      define :init, args: [:raw]
      define :init_with_model, args: [:raw, :model], action: :init
      define :process
    end
  end

  tools do
    tool(:read_sketches, Sketch, :read)
    tool(:create_sketch, Sketch, :init)
    tool(:process_sketch, Sketch, :process)
  end
end
