defmodule ImaginativeRestoration.Sketches do
  @moduledoc false
  use Ash.Domain

  resources do
    resource ImaginativeRestoration.Sketches.Sketch do
      define :init, args: [:unprocessed]
      define :process
    end
  end
end
