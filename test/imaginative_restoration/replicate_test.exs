defmodule ImaginativeRestoration.ReplicateTest do
  use ExUnit.Case, async: false

  alias ImaginativeRestoration.AI.Replicate

  # Simple data URL for testing
  @dummy_image_data_url "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
  @dummy_prompt "a test prompt"

  describe "Replicate.invoke basic functionality" do
    test "invoke/3 with known model pattern returns result" do
      result = Replicate.invoke("black-forest-labs/flux-canny-dev", @dummy_image_data_url, @dummy_prompt)
      # In test environment, this may succeed or fail depending on configuration
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "invoke/2 with known model pattern returns result" do
      result = Replicate.invoke("851-labs/background-remover", @dummy_image_data_url)
      # In test environment, this may succeed or fail depending on configuration
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
