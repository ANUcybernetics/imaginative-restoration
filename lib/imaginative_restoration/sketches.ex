defmodule ImaginativeRestoration.Sketches do
  @moduledoc false
  use Ash.Domain, extensions: [AshAi]

  alias ImaginativeRestoration.Sketches.Prompt
  alias ImaginativeRestoration.Sketches.Sketch

  resources do
    resource Sketch do
      define :init, args: [:raw]
      define :init_with_model, args: [:raw, :model], action: :init
      define :crop_and_label
      define :process
    end

    resource Prompt do
      define :latest_prompt, action: :latest
    end
  end

  tools do
    tool(:read_sketches, Sketch, :read)
    tool(:create_sketch, Sketch, :init)
    tool(:crop_and_label_sketch, Sketch, :crop_and_label)
    tool(:process_sketch, Sketch, :process)
    tool(:read_prompts, Prompt, :read)
    tool(:get_latest_prompt, Prompt, :latest)
  end
end
