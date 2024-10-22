defmodule ImaginativeRestoration.AI.JsonFixer do
  @moduledoc """
  Provides functionality to parse and fix incorrectly formatted JSON strings.

  This module offers methods to handle JSON-like strings that use single quotes
  instead of double quotes, and may contain escaped characters within the values.
  It's particularly useful for parsing JSON that has been incorrectly formatted
  but still maintains a valid structure.

  Currently, this is necessary because [florence-2-large](https://replicate.com/lucataco/florence-2-large)
  returns poorly formed responses.
  """
  def parse_incorrect_json(input) do
    input
    |> replace_outer_quotes()
    |> Jason.decode()
    |> case do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:error, "Failed to parse JSON"}
    end
  end

  defp replace_outer_quotes(input) do
    regex = ~r/\{'(.+?)': '((?:[^'\\]|\\.)*)'}/

    Regex.replace(regex, input, fn _, key, value ->
      escaped_value =
        value
        |> String.replace("\\", "\\\\")
        |> String.replace("\"", "\\\"")

      ~s({"#{key}": "#{escaped_value}"})
    end)
  end
end
