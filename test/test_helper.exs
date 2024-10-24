ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(ImaginativeRestoration.Repo, :manual)

defmodule ImaginativeRestoration.Fixtures do
  @moduledoc false

  def sketch_dataurl do
    File.read!("test/fixtures/sketch.jpg.dataurl")
  end
end
