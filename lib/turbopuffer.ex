defmodule Turbopuffer do
  @moduledoc """
  Elixir client library for the Turbopuffer vector database API.

  Turbopuffer is a vector database designed for efficient retrieval and search
  operations, supporting both vector similarity search and full-text search.

  ## Quick Start

      # Create a client
      client = Turbopuffer.new(api_key: "your-api-key")

      # Create a namespace reference
      namespace = Turbopuffer.namespace(client, "my-namespace")

      # Write vectors
      {:ok, _} = Turbopuffer.write(namespace,
        upsert_rows: [
          %{
            id: 1,
            vector: [0.1, 0.2, 0.3],
            attributes: %{
              "text" => "Sample document",
              "category" => "example"
            }
          }
        ]
      )

      # Query vectors
      {:ok, results} = Turbopuffer.query(namespace,
        vector: [0.1, 0.2, 0.3],
        top_k: 10
      )

      # Hybrid search
      {:ok, results} = Turbopuffer.hybrid_search(namespace,
        vector: [0.1, 0.2, 0.3],
        text_query: "machine learning",
        text_attribute: "text"
      )
  """

  alias Turbopuffer.{Client, Namespace, Vector, Search, Result}

  # Client options
  @type client_opts :: [
          {:api_key, String.t()}
          | {:region, :gcp_us_central1 | :gcp_europe_west4 | :gcp_asia_northeast1}
          | {:base_url, String.t()}
          | {:finch_name, atom()}
        ]

  @type request_opts :: [
          {:timeout, pos_integer()}
          | {:receive_timeout, pos_integer()}
        ]

  # Filter types
  # Filters support various operators and value types:
  # - Equality: %{"category" => "sports"}
  # - Inequality: %{"price" => %{"$gte" => 10.0, "$lte" => 100.0}}
  # - In/Not in: %{"status" => %{"$in" => ["active", "pending"]}}
  # - Null checks: %{"deleted_at" => nil}
  @type filter_value :: String.t() | number() | boolean() | nil | [String.t() | number()]
  @type filter_operator :: filter_value | %{String.t() => filter_value}
  @type filters :: %{String.t() => filter_operator}

  # Schema types for namespace configuration
  @type schema_field :: %{
          optional(String.t()) => String.t() | boolean() | map()
        }
  @type schema :: %{String.t() => schema_field()}

  # Response types
  @type query_response :: [Result.t()]
  @type success_response :: %{} | %{String.t() => any()}

  # Vector options
  @type vector_upsert_opts :: [
          {:distance_metric, String.t()}
          | {:schema, schema()}
        ]

  @type vector_query_opts :: [
          {:vector, [float()]}
          | {:top_k, pos_integer()}
          | {:distance_metric, String.t()}
          | {:include_attributes, boolean() | [String.t()]}
          | {:include_vectors, boolean()}
          | {:filters, filters()}
        ]

  # Search options
  @type text_search_opts :: [
          {:query, String.t()}
          | {:attribute, String.t()}
          | {:top_k, pos_integer()}
          | {:include_attributes, boolean() | [String.t()]}
          | {:filters, filters()}
        ]

  @type hybrid_search_opts :: [
          {:vector, [float()]}
          | {:text_query, String.t()}
          | {:text_attribute, String.t()}
          | {:top_k, pos_integer()}
          | {:include_attributes, boolean() | [String.t()]}
          | {:fusion_method, :rrf | :weighted}
        ]

  @type multi_query_opts :: [
          {:queries, [map()]}
          | {:top_k, pos_integer()}
          | {:include_attributes, boolean() | [String.t()]}
        ]

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
  @spec new(client_opts()) :: Client.t()
  defdelegate new(opts), to: Client

  @doc """
  Creates a namespace reference.

  ## Examples

      namespace = Turbopuffer.namespace(client, "my-namespace")
  """
  @spec namespace(Client.t(), String.t()) :: Namespace.t()
  defdelegate namespace(client, name), to: Namespace, as: :new

  @doc """
  Writes vectors to a namespace (upserts and/or deletes).

  ## Options
    * `:upsert_rows` - List of vectors to upsert
    * `:deletes` - List of IDs to delete
    * `:distance_metric` - The distance metric to use (e.g., "cosine_distance", "euclidean_squared")
    * `:schema` - Schema configuration for attributes

  ## Examples

      # Upsert and delete in one operation
      {:ok, _} = Turbopuffer.write(namespace,
        upsert_rows: [
          %{id: 1, vector: [0.1, 0.2], attributes: %{"text" => "doc"}}
        ],
        deletes: [2, 3],
        distance_metric: "cosine_distance"
      )

      # Upsert with flat attributes
      {:ok, _} = Turbopuffer.write(namespace,
        upsert_rows: [
          %{id: 4, vector: [0.3, 0.4], text: "another doc", category: "example"}
        ]
      )
  """
  @spec write(Namespace.t(), keyword()) :: {:ok, success_response()} | {:error, term()}
  defdelegate write(namespace, opts), to: Vector

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
  @spec query(Namespace.t(), vector_query_opts()) :: {:ok, query_response()} | {:error, term()}
  defdelegate query(namespace, opts), to: Vector

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
  @spec text_search(Namespace.t(), text_search_opts()) ::
          {:ok, query_response()} | {:error, term()}
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
  @spec hybrid_search(Namespace.t(), hybrid_search_opts()) ::
          {:ok, query_response()} | {:error, term()}
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
  @spec multi_query(Namespace.t(), multi_query_opts()) ::
          {:ok, query_response()} | {:error, term()}
  defdelegate multi_query(namespace, opts), to: Search

  @doc """
  Deletes a namespace.

  ## Examples

      {:ok, _} = Turbopuffer.delete_namespace(namespace)
  """
  @spec delete_namespace(Namespace.t()) :: {:ok, success_response()} | {:error, term()}
  defdelegate delete_namespace(namespace), to: Namespace, as: :delete
end
