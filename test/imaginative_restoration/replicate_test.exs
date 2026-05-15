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
end
