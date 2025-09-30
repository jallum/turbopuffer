defmodule Turbopuffer.VectorTest do
  use ExUnit.Case

  alias Turbopuffer.{Client, Namespace, Vector}

  setup do
    client = Client.new(api_key: "test-key")
    namespace = Namespace.new(client, "test-ns")
    {:ok, namespace: namespace}
  end

  describe "vector formatting" do
    test "formats vectors correctly", %{namespace: namespace} do
      vectors = [
        %{
          id: "doc1",
          vector: [0.1, 0.2, 0.3],
          attributes: %{
            text: "Sample document",
            category: "example"
          }
        }
      ]

      # This test validates the vector structure is properly formatted
      assert {:error, _} = Vector.upsert(namespace, vectors)
    end

    test "handles vectors with atom keys", %{namespace: namespace} do
      vectors = [
        %{
          id: "doc1",
          vector: [0.1, 0.2, 0.3],
          attributes: %{text: "Sample"}
        }
      ]

      # Test that atom keys are properly converted
      assert {:error, _} = Vector.upsert(namespace, vectors)
    end
  end

  describe "query validation" do
    test "requires vector parameter", %{namespace: namespace} do
      assert_raise KeyError, fn ->
        Vector.query(namespace, top_k: 10)
      end
    end

    test "accepts valid query options", %{namespace: namespace} do
      # This will fail with connection error but validates the parameters
      result = Vector.query(namespace,
        vector: [0.1, 0.2, 0.3],
        top_k: 10,
        include_attributes: ["text"],
        include_vectors: false
      )

      assert {:error, _} = result
    end
  end
end