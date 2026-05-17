defmodule ImaginativeRestoration.ReplicateTest do
  use ExUnit.Case, async: false

  alias ImaginativeRestoration.AI.Replicate

  describe "extract_output/2" do
    test "pulls bare URL output from background remover" do
      assert {:ok, "https://example.com/out.webp"} =
               Replicate.extract_output("851-labs/background-remover", %{
                 "status" => "succeeded",
                 "output" => "https://example.com/out.webp"
               })
    end

    test "skips the canny edge map from t2i-adapter-sdxl" do
      assert {:ok, "https://example.com/result.webp"} =
               Replicate.extract_output("adirik/t2i-adapter-sdxl-canny", %{
                 "status" => "succeeded",
                 "output" => ["https://example.com/canny.webp", "https://example.com/result.webp"]
               })
    end

    test "unwraps single-element list output from flux-canny-dev" do
      assert {:ok, "https://example.com/result.webp"} =
               Replicate.extract_output("black-forest-labs/flux-canny-dev", %{
                 "status" => "succeeded",
                 "output" => ["https://example.com/result.webp"]
               })
    end

    test "skips the control map from sdxl-lightning-multi-controlnet" do
      assert {:ok, "https://example.com/result.webp"} =
               Replicate.extract_output("lucataco/sdxl-lightning-multi-controlnet", %{
                 "status" => "succeeded",
                 "output" => ["https://example.com/lineart.webp", "https://example.com/result.webp"]
               })
    end

    test "pulls bare URL output from birefnet" do
      assert {:ok, "https://example.com/out.webp"} =
               Replicate.extract_output("men1scus/birefnet", %{
                 "status" => "succeeded",
                 "output" => "https://example.com/out.webp"
               })
    end

    test "returns error for failed predictions" do
      assert {:error, "boom"} =
               Replicate.extract_output("any/model", %{"status" => "failed", "error" => "boom"})
    end
  end

  describe "verify_signature/5" do
    test "accepts a signature computed with the same secret" do
      secret = "whsec_" <> Base.encode64("test-secret-key")
      body = ~s({"id":"abc"})
      webhook_id = "msg_123"
      webhook_timestamp = "1700000000"

      payload = "#{webhook_id}.#{webhook_timestamp}.#{body}"
      {:ok, key} = "test-secret-key" |> Base.encode64() |> Base.decode64()

      expected =
        :hmac
        |> :crypto.mac(:sha256, key, payload)
        |> Base.encode64()

      header = "v1,#{expected}"

      assert :ok = Replicate.verify_signature(body, webhook_id, webhook_timestamp, header, secret)
    end

    test "rejects a tampered body" do
      secret = "whsec_" <> Base.encode64("test-secret-key")
      header = "v1,not-a-real-signature"

      assert {:error, :invalid_signature} =
               Replicate.verify_signature(~s({"id":"abc"}), "msg_123", "1700000000", header, secret)
    end
  end

  # Hits the real Replicate API to confirm every model referenced in the
  # codebase still exists and is callable. Excluded from `mix test` by default;
  # run with `mise exec -- mix test --only replicate_live`.
  describe "live model availability" do
    @models [
      "adirik/t2i-adapter-sdxl-canny",
      "philz1337x/controlnet-deliberate",
      "xlabs-ai/flux-dev-controlnet",
      "black-forest-labs/flux-canny-dev",
      "lucataco/sdxl-lightning-multi-controlnet",
      "lucataco/remove-bg",
      "851-labs/background-remover",
      "men1scus/birefnet"
    ]

    for model <- @models do
      @tag :replicate_live
      test "#{model} is reachable on Replicate" do
        model = unquote(model)
        # Bypass the get_latest_version cache so a stale entry can't mask a
        # removed/renamed model.
        :persistent_term.erase({Replicate, :version, model})

        url = "https://api.replicate.com/v1/models/#{model}"
        token = System.fetch_env!("REPLICATE_API_TOKEN")

        assert {:ok, %{status: 200}} = Req.get(url, auth: {:bearer, token}),
               "model #{model} not reachable"

        if String.starts_with?(model, "black-forest-labs/") do
          # Official models — Replicate.get_latest_version is a no-op for these,
          # so the model-info GET above is the real check.
          assert {:ok, ^model} = Replicate.get_latest_version(model)
        else
          assert {:ok, version} = Replicate.get_latest_version(model)
          assert is_binary(version) and version != ""
        end
      end
    end
  end
end
