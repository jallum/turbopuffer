defmodule Turbopuffer.Search do
  @moduledoc """
  Handles text and hybrid search operations for Turbopuffer.
  """

  alias Turbopuffer.{Client, Namespace}

  @doc """
  Performs a full-text search using BM25 ranking.

  ## Options
    * `:query` - The text query string (required)
    * `:attribute` - The attribute to search in (required)
    * `:top_k` - Number of results to return (default: 10)
    * `:include_attributes` - List of attributes to include in results
    * `:filters` - Additional metadata filters

  ## Examples

      Turbopuffer.Search.text(namespace,
        query: "machine learning",
        attribute: "content",
        top_k: 20
      )
  """
  @spec text(Namespace.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def text(%Namespace{} = namespace, opts) do
    query = Keyword.fetch!(opts, :query)
    attribute = Keyword.fetch!(opts, :attribute)
    top_k = Keyword.get(opts, :top_k, 10)
    include_attributes = Keyword.get(opts, :include_attributes, true)
    filters = Keyword.get(opts, :filters)

    path = "/v2/namespaces/#{namespace.name}/query"

    body =
      %{
        "rank_by" => [attribute, "BM25", query],
        "top_k" => top_k,
        "include_attributes" => include_attributes
      }
      |> maybe_add_field("filters", filters)

    case Client.post(namespace.client, path, body) do
      {:ok, %{"vectors" => vectors}} -> {:ok, vectors}
      {:ok, response} -> {:ok, response}
      error -> error
    end
  end

  @doc """
  Performs a hybrid search combining vector and text search.

  ## Options
    * `:vector` - The query vector
    * `:text_query` - The text query string
    * `:text_attribute` - The attribute to search text in
    * `:top_k` - Number of results per query (default: 10)
    * `:include_attributes` - List of attributes to include
    * `:fusion_method` - Method to combine results (:rrf or :weighted, default: :rrf)

  ## Examples

      Turbopuffer.Search.hybrid(namespace,
        vector: [0.1, 0.2, 0.3],
        text_query: "machine learning",
        text_attribute: "content",
        top_k: 20
      )
  """
  @spec hybrid(Namespace.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def hybrid(%Namespace{} = namespace, opts) do
    queries = build_hybrid_queries(opts)

    multi_query(namespace,
      queries: queries,
      top_k: Keyword.get(opts, :top_k, 10),
      include_attributes: Keyword.get(opts, :include_attributes, true)
    )
  end

  @doc """
  Performs multiple queries with rank fusion.

  ## Options
    * `:queries` - List of query configurations
    * `:top_k` - Number of results to return (default: 10)
    * `:include_attributes` - Attributes to include in results

  ## Examples

      queries = [
        %{rank_by: [:vector, :ann, [0.1, 0.2, 0.3]], top_k: 10},
        %{rank_by: ["content", "BM25", "search terms"], top_k: 10}
      ]

      Turbopuffer.Search.multi_query(namespace,
        queries: queries,
        top_k: 20
      )
  """
  @spec multi_query(Namespace.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def multi_query(%Namespace{} = namespace, opts) do
    queries = Keyword.fetch!(opts, :queries)
    top_k = Keyword.get(opts, :top_k, 10)
    include_attributes = Keyword.get(opts, :include_attributes, true)

    path = "/v2/namespaces/#{namespace.name}/multi_query"

    formatted_queries =
      Enum.map(queries, fn query ->
        format_query(query, include_attributes)
      end)

    body = %{
      "queries" => formatted_queries,
      "top_k" => top_k
    }

    case Client.post(namespace.client, path, body) do
      {:ok, %{"vectors" => vectors}} -> {:ok, vectors}
      {:ok, response} -> {:ok, response}
      error -> error
    end
  end

  defp build_hybrid_queries(opts) do
    queries = []

    # Add vector query if provided
    queries =
      case Keyword.fetch(opts, :vector) do
        {:ok, vector} ->
          vector_query = %{
            rank_by: [:vector, :ann, vector],
            top_k: Keyword.get(opts, :top_k, 10)
          }
          [vector_query | queries]

        :error ->
          queries
      end

    # Add text query if provided
    queries =
      case {Keyword.fetch(opts, :text_query), Keyword.fetch(opts, :text_attribute)} do
        {{:ok, text_query}, {:ok, text_attribute}} ->
          text_query = %{
            rank_by: [text_attribute, "BM25", text_query],
            top_k: Keyword.get(opts, :top_k, 10)
          }
          [text_query | queries]

        _ ->
          queries
      end

    if queries == [] do
      raise ArgumentError, "At least one of :vector or :text_query/:text_attribute must be provided"
    end

    queries
  end

  defp format_query(%{rank_by: rank_by} = query, include_attributes) do
    formatted_rank_by =
      case rank_by do
        [:vector, :ann, vector] ->
          ["vector", "ANN", vector]

        [attribute, "BM25", text] when is_binary(attribute) ->
          [attribute, "BM25", text]

        [attribute, method, value] ->
          [to_string(attribute), to_string(method), value]

        _ ->
          rank_by
      end

    %{
      "rank_by" => formatted_rank_by,
      "top_k" => Map.get(query, :top_k, 10),
      "include_attributes" => Map.get(query, :include_attributes, include_attributes)
    }
  end

  defp maybe_add_field(map, _key, nil), do: map
  defp maybe_add_field(map, key, value), do: Map.put(map, key, value)
end