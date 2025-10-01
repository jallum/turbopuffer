defmodule Turbopuffer.Search do
  @moduledoc """
  Handles text and hybrid search operations for Turbopuffer.
  """

  alias Turbopuffer.{Client, Namespace, Result}

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
  @spec text(Namespace.t(), Turbopuffer.text_search_opts()) ::
          {:ok, Turbopuffer.query_response()} | {:error, term()}
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
      |> maybe_add_field("filters", format_filters(filters))

    case Client.post(namespace.client, path, body) do
      {:ok, %{"rows" => rows}} when is_list(rows) ->
        {:ok, Result.from_maps(rows)}

      {:ok, %{"vectors" => vectors}} when is_list(vectors) ->
        {:ok, Result.from_maps(vectors)}

      {:ok, %{"data" => vectors}} when is_list(vectors) ->
        {:ok, Result.from_maps(vectors)}

      {:ok, _response} ->
        {:ok, []}

      error ->
        error
    end
  end

  @doc """
  Performs a hybrid search combining vector and text search.

  ## Options
    * `:vector` - The query vector (required)
    * `:text_query` - The text query string (required)
    * `:text_attribute` - The attribute to search text in (required)
    * `:top_k` - Number of results to return (default: 10)
    * `:include_attributes` - List of attributes to include (default: true)
    * `:filters` - Metadata filters to apply

  ## Examples

      Turbopuffer.Search.hybrid(namespace,
        vector: [0.1, 0.2, 0.3],
        text_query: "machine learning",
        text_attribute: "content",
        top_k: 20,
        filters: %{"category" => "tutorial"}
      )
  """
  @spec hybrid(Namespace.t(), Turbopuffer.hybrid_search_opts()) ::
          {:ok, Turbopuffer.query_response()} | {:error, term()}
  def hybrid(%Namespace{} = namespace, opts) do
    vector = Keyword.fetch!(opts, :vector)
    text_query = Keyword.fetch!(opts, :text_query)
    text_attribute = Keyword.fetch!(opts, :text_attribute)
    top_k = Keyword.get(opts, :top_k, 10)
    include_attributes = Keyword.get(opts, :include_attributes, true)
    filters = Keyword.get(opts, :filters)

    # Use multi_query for hybrid search
    queries = [
      %{
        rank_by: ["vector", "ANN", vector],
        top_k: top_k,
        include_attributes: include_attributes,
        filters: filters
      },
      %{
        rank_by: [text_attribute, "BM25", text_query],
        top_k: top_k,
        include_attributes: include_attributes,
        filters: filters
      }
    ]

    multi_query(namespace,
      queries: queries,
      top_k: top_k
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
        %{rank_by: ["vector", "ANN", [0.1, 0.2, 0.3]], top_k: 10},
        %{rank_by: ["content", "BM25", "search terms"], top_k: 10}
      ]

      Turbopuffer.Search.multi_query(namespace,
        queries: queries,
        top_k: 20
      )
  """
  @spec multi_query(Namespace.t(), Turbopuffer.multi_query_opts()) ::
          {:ok, Turbopuffer.query_response()} | {:error, term()}
  def multi_query(%Namespace{} = namespace, opts) do
    queries = Keyword.fetch!(opts, :queries)
    top_k = Keyword.get(opts, :top_k, 10)
    include_attributes = Keyword.get(opts, :include_attributes, true)

    path = "/v2/namespaces/#{namespace.name}/query?stainless_overload=multiQuery"

    formatted_queries =
      Enum.map(queries, fn query ->
        format_query(query, include_attributes)
      end)

    body = %{
      "queries" => formatted_queries,
      "top_k" => top_k
    }

    case Client.post(namespace.client, path, body) do
      {:ok, %{"results" => results}} when is_list(results) ->
        # Multi-query returns results array, each with its own rows
        # We need to merge/deduplicate the rows from all query results
        all_rows =
          results
          |> Enum.flat_map(fn %{"rows" => rows} -> rows || [] end)
          |> Enum.uniq_by(&Map.get(&1, "id"))

        {:ok, Result.from_maps(all_rows)}

      {:ok, %{"rows" => rows}} when is_list(rows) ->
        {:ok, Result.from_maps(rows)}

      {:ok, %{"vectors" => vectors}} when is_list(vectors) ->
        {:ok, Result.from_maps(vectors)}

      {:ok, _response} ->
        {:ok, []}

      error ->
        error
    end
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

    result = %{
      "rank_by" => formatted_rank_by,
      "top_k" => Map.get(query, :top_k, 10),
      "include_attributes" => Map.get(query, :include_attributes, include_attributes)
    }

    # Add filters if present
    case Map.get(query, :filters) do
      nil -> result
      filters -> Map.put(result, "filters", format_filters(filters))
    end
  end

  defp maybe_add_field(map, _key, nil), do: map
  defp maybe_add_field(map, key, value), do: Map.put(map, key, value)

  # Convert map filters to tuple format expected by API
  defp format_filters(nil), do: nil

  defp format_filters(filters) when is_map(filters) do
    conditions =
      Enum.map(filters, fn {key, value} ->
        [to_string(key), "Eq", value]
      end)

    case conditions do
      [single] -> single
      multiple -> ["And" | [multiple]]
    end
  end

  defp format_filters(filters), do: filters
end
