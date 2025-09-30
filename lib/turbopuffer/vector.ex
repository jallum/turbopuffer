defmodule Turbopuffer.Vector do
  @moduledoc """
  Handles vector operations for Turbopuffer.
  """

  alias Turbopuffer.{Client, Namespace}

  @doc """
  Upserts vectors into a namespace.

  ## Examples

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
      Turbopuffer.Vector.upsert(namespace, vectors)
  """
  @spec upsert(Namespace.t(), list(map())) :: {:ok, map()} | {:error, term()}
  def upsert(%Namespace{} = namespace, vectors) when is_list(vectors) do
    path = "/v2/namespaces/#{namespace.name}/vectors"
    body = %{"vectors" => format_vectors(vectors)}
    Client.post(namespace.client, path, body)
  end

  @doc """
  Queries vectors by similarity.

  ## Options
    * `:vector` - The query vector (required)
    * `:top_k` - Number of results to return (default: 10)
    * `:distance_metric` - Distance metric to use
    * `:include_attributes` - List of attributes to include in results
    * `:filters` - Metadata filters to apply
    * `:include_vectors` - Whether to include vectors in results (default: false)

  ## Examples

      Turbopuffer.Vector.query(namespace,
        vector: [0.1, 0.2, 0.3],
        top_k: 10,
        include_attributes: ["text", "category"]
      )
  """
  @spec query(Namespace.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def query(%Namespace{} = namespace, opts) do
    vector = Keyword.fetch!(opts, :vector)
    top_k = Keyword.get(opts, :top_k, 10)
    include_attributes = Keyword.get(opts, :include_attributes, true)
    include_vectors = Keyword.get(opts, :include_vectors, false)
    filters = Keyword.get(opts, :filters)
    distance_metric = Keyword.get(opts, :distance_metric)

    path = "/v2/namespaces/#{namespace.name}/query"

    body =
      %{
        "vector" => vector,
        "top_k" => top_k,
        "include_attributes" => include_attributes,
        "include_vectors" => include_vectors
      }
      |> maybe_add_field("filters", filters)
      |> maybe_add_field("distance_metric", distance_metric)

    case Client.post(namespace.client, path, body) do
      {:ok, %{"vectors" => vectors}} -> {:ok, vectors}
      {:ok, response} -> {:ok, response}
      error -> error
    end
  end

  @doc """
  Deletes vectors by ID.

  ## Examples

      Turbopuffer.Vector.delete(namespace, ["doc1", "doc2"])
  """
  @spec delete(Namespace.t(), list(String.t())) :: {:ok, map()} | {:error, term()}
  def delete(%Namespace{} = namespace, ids) when is_list(ids) do
    path = "/v2/namespaces/#{namespace.name}/vectors"
    query = URI.encode_query(Enum.map(ids, fn id -> {"id", id} end))
    Client.delete(namespace.client, path <> "?" <> query)
  end

  @doc """
  Gets vectors by ID.

  ## Examples

      Turbopuffer.Vector.get(namespace, ["doc1", "doc2"])
  """
  @spec get(Namespace.t(), list(String.t()), keyword()) :: {:ok, list(map())} | {:error, term()}
  def get(%Namespace{} = namespace, ids, opts \\ []) when is_list(ids) do
    include_attributes = Keyword.get(opts, :include_attributes, true)
    include_vectors = Keyword.get(opts, :include_vectors, false)

    path = "/v2/namespaces/#{namespace.name}/vectors/fetch"

    body = %{
      "ids" => ids,
      "include_attributes" => include_attributes,
      "include_vectors" => include_vectors
    }

    case Client.post(namespace.client, path, body) do
      {:ok, %{"vectors" => vectors}} -> {:ok, vectors}
      {:ok, response} -> {:ok, response}
      error -> error
    end
  end

  defp format_vectors(vectors) do
    Enum.map(vectors, fn vector ->
      vector
      |> Map.put_new("attributes", %{})
      |> ensure_string_key("id")
      |> ensure_string_key("vector")
      |> ensure_string_key("attributes")
    end)
  end

  defp ensure_string_key(map, key) when is_atom(key) do
    atom_key = key
    string_key = Atom.to_string(key)

    case Map.fetch(map, atom_key) do
      {:ok, value} ->
        map
        |> Map.delete(atom_key)
        |> Map.put(string_key, value)

      :error ->
        map
    end
  end

  defp ensure_string_key(map, _key), do: map

  defp maybe_add_field(map, _key, nil), do: map
  defp maybe_add_field(map, key, value), do: Map.put(map, key, value)
end