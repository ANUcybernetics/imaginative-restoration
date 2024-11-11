defmodule ImaginativeRestoration.Sketches do
  @moduledoc false
  use Ash.Domain

  resources do
    resource ImaginativeRestoration.Sketches.Sketch do
      define :init, args: [:raw]
      define :init_with_model, args: [:raw, :model], action: :init
      define :crop_and_set_prompt
      define :process
    end

    resource ImaginativeRestoration.Sketches.Prompt do
      define :latest_prompt, action: :latest
    end
  end
end
