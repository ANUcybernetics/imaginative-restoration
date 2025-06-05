defmodule ImaginativeRestoration.Sketches.Prompt do
  @moduledoc """
  Provides hardcoded prompts for image generation.
  """

  @prompts [
    "prompt one",
    "prompt two"
  ]

  @doc """
  Returns a random prompt from the predefined list.
  """
  def random_prompt do
    Enum.random(@prompts)
  end

  @doc """
  Returns all available prompts.
  """
  def all_prompts do
    @prompts
  end
end
