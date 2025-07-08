defmodule ImaginativeRestoration.Sketches.PromptTest do
  use ExUnit.Case, async: false

  alias ImaginativeRestoration.Sketches.Prompt

  describe "random_prompt/0" do
    test "returns a non-empty string" do
      prompt = Prompt.random_prompt()
      assert is_binary(prompt)
      assert String.length(prompt) > 0
    end
  end
end
