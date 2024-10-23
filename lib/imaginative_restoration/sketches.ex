defmodule ImaginativeRestoration.Sketches do
  @moduledoc false
  use Ash.Domain

  resources do
    resource ImaginativeRestoration.Sketches.Sketch do
      define :process, args: [:unprocessed]
    end
  end
end
