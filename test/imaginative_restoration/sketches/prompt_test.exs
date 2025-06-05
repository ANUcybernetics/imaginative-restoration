defmodule ImaginativeRestoration.Sketches.PromptTest do
  use ExUnit.Case, async: true

  alias ImaginativeRestoration.Sketches.Prompt

  describe "all_prompts/0" do
    test "returns list of prompts" do
      prompts = Prompt.all_prompts()
      assert is_list(prompts)
      assert length(prompts) > 0
      assert Enum.all?(prompts, &is_binary/1)
    end
  end

  describe "random_prompt/0" do
    test "returns a valid prompt" do
      prompt = Prompt.random_prompt()
      assert is_binary(prompt)
      assert prompt in Prompt.all_prompts()
    end
  end
end
