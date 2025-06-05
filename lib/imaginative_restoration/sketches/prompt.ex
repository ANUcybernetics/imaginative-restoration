defmodule ImaginativeRestoration.Sketches.Prompt do
  @moduledoc """
  Provides dynamic prompts for image generation by combining random elements
  from three categories: descriptive adjectives, sea creatures, and style references.
  """

  @descriptive_adjectives [
    "majestic, ethereal",
    "brilliantly-colored",
    "grimy, deep-sea",
    "venerable and ancient"
  ]

  @sea_creatures [
    "octopus",
    "jellyfish",
    "seahorse",
    "manta ray",
    "shark",
    "fish",
    "whale"
  ]

  @style_references [
    "Art Nouveau",
    "Japanese woodblock print",
    "Renaissance painting",
    "cyberpunk digital art",
    "a photorealistic nature documentary"
  ]

  @doc """
  Returns a random prompt by combining elements from each category.
  Format: "a [DESCRIPTIVE_ADJECTIVE] [SEA_CREATURE] in the style of [STYLE_REFERENCE]"
  """
  def random_prompt do
    adjective = Enum.random(@descriptive_adjectives)
    creature = Enum.random(@sea_creatures)
    style = Enum.random(@style_references)

    "a #{adjective} #{creature}-like creature in the style of #{style} on a plain white background"
  end
end
