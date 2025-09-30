defmodule Turbopuffer do
  @moduledoc """
  Elixir client library for the Turbopuffer vector database API.

  Turbopuffer is a vector database designed for efficient retrieval and search
  operations, supporting both vector similarity search and full-text search.

  ## Quick Start

      # Create a client
      client = Turbopuffer.new(api_key: "your-api-key")

      # Get or create a namespace
      {:ok, namespace} = Turbopuffer.namespace(client, "my-namespace")

      # Upsert vectors
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
      {:ok, _} = Turbopuffer.upsert(namespace, vectors)

      # Query vectors
      {:ok, results} = Turbopuffer.query(namespace,
        vector: [0.1, 0.2, 0.3],
        top_k: 10
      )

      # Hybrid search
      {:ok, results} = Turbopuffer.hybrid_search(namespace,
        vector: [0.1, 0.2, 0.3],
        text_query: "machine learning",
        text_attribute: "content"
      )
  """

  alias Turbopuffer.{Client, Namespace, Vector, Search}

  @doc """
  Creates a new Turbopuffer client.

  ## Options
    * `:api_key` - The API key for authentication (can also use TURBOPUFFER_API_KEY env var)
    * `:region` - The region to connect to (defaults to :gcp_us_central1)
    * `:base_url` - Override the base URL for the API

  ## Examples

      client = Turbopuffer.new(api_key: "your-key")

      # With specific region
      client = Turbopuffer.new(
        api_key: "your-key",
        region: :gcp_europe_west4
      )
  """
  @spec new(keyword()) :: Client.t()
  defdelegate new(opts), to: Client

  @doc """
  Gets or creates a namespace reference.

  ## Examples

      {:ok, namespace} = Turbopuffer.namespace(client, "my-namespace")
  """
  @spec namespace(Client.t(), String.t()) :: {:ok, Namespace.t()}
  def namespace(client, name) do
    {:ok, Namespace.new(client, name)}
  end

  @doc """
  Creates a namespace with configuration.

  ## Options
    * `:distance_metric` - The distance metric to use (default: "cosine_distance")
    * `:schema` - Schema configuration for full-text search

  ## Examples

      {:ok, _} = Turbopuffer.create_namespace(namespace,
        schema: %{
          "content" => %{"type" => "string", "full_text_search" => true}
        }
      )
  """
  @spec create_namespace(Namespace.t(), keyword()) :: {:ok, map()} | {:error, term()}
  defdelegate create_namespace(namespace, opts \\ []), to: Namespace, as: :create

  @doc """
  Lists all namespaces.

  ## Examples

      {:ok, namespaces} = Turbopuffer.list_namespaces(client)
  """
  @spec list_namespaces(Client.t()) :: {:ok, list(String.t())} | {:error, term()}
  defdelegate list_namespaces(client), to: Namespace, as: :list

  @doc """
  Deletes a namespace.

  ## Examples

      {:ok, _} = Turbopuffer.delete_namespace(namespace)
  """
  @spec delete_namespace(Namespace.t()) :: {:ok, map()} | {:error, term()}
  defdelegate delete_namespace(namespace), to: Namespace, as: :delete

  @doc """
  Gets namespace statistics.

  ## Examples

      {:ok, stats} = Turbopuffer.namespace_stats(namespace)
  """
  @spec namespace_stats(Namespace.t()) :: {:ok, map()} | {:error, term()}
  defdelegate namespace_stats(namespace), to: Namespace, as: :stats

  @doc """
  Upserts vectors into a namespace.

  ## Examples

      vectors = [
        %{
          id: "doc1",
          vector: [0.1, 0.2, 0.3],
          attributes: %{text: "Sample document"}
        }
      ]
      {:ok, _} = Turbopuffer.upsert(namespace, vectors)
  """
  @spec upsert(Namespace.t(), list(map())) :: {:ok, map()} | {:error, term()}
  defdelegate upsert(namespace, vectors), to: Vector

  @doc """
  Queries vectors by similarity.

  ## Options
    * `:vector` - The query vector (required)
    * `:top_k` - Number of results to return (default: 10)
    * `:include_attributes` - List of attributes to include
    * `:filters` - Metadata filters

  ## Examples

      {:ok, results} = Turbopuffer.query(namespace,
        vector: [0.1, 0.2, 0.3],
        top_k: 10
      )
  """
  @spec query(Namespace.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  defdelegate query(namespace, opts), to: Vector

  @doc """
  Gets vectors by ID.

  ## Examples

      {:ok, vectors} = Turbopuffer.get_vectors(namespace, ["doc1", "doc2"])
  """
  @spec get_vectors(Namespace.t(), list(String.t()), keyword()) :: {:ok, list(map())} | {:error, term()}
  defdelegate get_vectors(namespace, ids, opts \\ []), to: Vector, as: :get

  @doc """
  Deletes vectors by ID.

  ## Examples

      {:ok, _} = Turbopuffer.delete_vectors(namespace, ["doc1", "doc2"])
  """
  @spec delete_vectors(Namespace.t(), list(String.t())) :: {:ok, map()} | {:error, term()}
  defdelegate delete_vectors(namespace, ids), to: Vector, as: :delete

  @doc """
  Performs full-text search.

  ## Options
    * `:query` - The text query (required)
    * `:attribute` - The attribute to search in (required)
    * `:top_k` - Number of results (default: 10)

  ## Examples

      {:ok, results} = Turbopuffer.text_search(namespace,
        query: "machine learning",
        attribute: "content",
        top_k: 20
      )
  """
  @spec text_search(Namespace.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  defdelegate text_search(namespace, opts), to: Search, as: :text

  @doc """
  Performs hybrid search combining vector and text.

  ## Options
    * `:vector` - The query vector
    * `:text_query` - The text query
    * `:text_attribute` - The attribute for text search
    * `:top_k` - Number of results (default: 10)

  ## Examples

      {:ok, results} = Turbopuffer.hybrid_search(namespace,
        vector: [0.1, 0.2, 0.3],
        text_query: "machine learning",
        text_attribute: "content",
        top_k: 20
      )
  """
  @spec hybrid_search(Namespace.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  defdelegate hybrid_search(namespace, opts), to: Search, as: :hybrid

  @doc """
  Performs multiple queries with rank fusion.

  ## Options
    * `:queries` - List of query configurations
    * `:top_k` - Number of final results

  ## Examples

      queries = [
        %{rank_by: [:vector, :ann, [0.1, 0.2, 0.3]], top_k: 10},
        %{rank_by: ["content", "BM25", "search terms"], top_k: 10}
      ]
      {:ok, results} = Turbopuffer.multi_query(namespace, queries: queries)
  """
  @spec multi_query(Namespace.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  defdelegate multi_query(namespace, opts), to: Search
end
