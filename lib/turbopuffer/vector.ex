defmodule Turbopuffer.Vector do
  @moduledoc """
  Handles vector operations for Turbopuffer.
  """

  alias Turbopuffer.{Client, Namespace, Result}

  @doc """
  Writes vectors to a namespace (upserts, patches, and/or deletes).

  ## Options
    * `:upsert_rows` - List of vectors to upsert
    * `:upsert_columns` - Column-based vector upsert
    * `:patch_rows` - List of partial updates
    * `:patch_columns` - Column-based partial updates
    * `:deletes` - List of IDs to delete
    * `:delete_by_filter` - Delete documents matching filter
    * `:distance_metric` - The distance metric to use (e.g., "cosine_distance", "euclidean_squared")
    * `:schema` - Schema configuration for attributes
    * `:upsert_condition` - Conditional upsert based on existing state
    * `:patch_condition` - Conditional patch
    * `:delete_condition` - Conditional delete
    * `:copy_from_namespace` - Copy all documents from another namespace
    * `:encryption` - Customer managed encryption configuration

  ## Examples

      # Upsert vectors with nested attributes
      Turbopuffer.Vector.write(namespace,
        upsert_rows: [
          %{
            id: 1,
            vector: [0.1, 0.2, 0.3],
            attributes: %{"text" => "Sample document", "category" => "doc"}
          }
        ],
        distance_metric: "cosine_distance",
        schema: %{
          "text" => %{"type" => "string", "full_text_search" => true}
        }
      )

      # Upsert with flat attributes (attributes directly in the map)
      Turbopuffer.Vector.write(namespace,
        upsert_rows: [
          %{
            id: 2,
            vector: [0.4, 0.5, 0.6],
            text: "Another document",
            category: "doc"
          }
        ]
      )

      # Delete vectors by ID
      Turbopuffer.Vector.write(namespace,
        deletes: [1, 2, 3]
      )
  """
  @spec write(Namespace.t(), keyword()) ::
          {:ok, Turbopuffer.success_response()} | {:error, term()}
  def write(%Namespace{} = namespace, opts \\ []) do
    path = "/v2/namespaces/#{namespace.name}"

    body =
      opts
      |> Enum.reduce(%{}, &build_write_body/2)

    Client.post(namespace.client, path, body)
  end

  # Pattern match on write options and build the request body
  defp build_write_body({:upsert_rows, []}, acc), do: acc
  defp build_write_body({:upsert_rows, rows}, acc) do
    Map.put(acc, "upsert_rows", format_write_vectors(rows))
  end

  defp build_write_body({:patch_rows, []}, acc), do: acc
  defp build_write_body({:patch_rows, rows}, acc) do
    Map.put(acc, "patch_rows", format_write_vectors(rows))
  end

  defp build_write_body({:deletes, []}, acc), do: acc
  defp build_write_body({:deletes, ids}, acc) do
    Map.put(acc, "deletes", ids)
  end

  defp build_write_body({:upsert_columns, nil}, acc), do: acc
  defp build_write_body({:upsert_columns, columns}, acc) do
    Map.put(acc, "upsert_columns", columns)
  end

  defp build_write_body({:patch_columns, nil}, acc), do: acc
  defp build_write_body({:patch_columns, columns}, acc) do
    Map.put(acc, "patch_columns", columns)
  end

  defp build_write_body({:delete_by_filter, nil}, acc), do: acc
  defp build_write_body({:delete_by_filter, filter}, acc) do
    Map.put(acc, "delete_by_filter", filter)
  end

  defp build_write_body({:distance_metric, nil}, acc), do: acc
  defp build_write_body({:distance_metric, metric}, acc) do
    Map.put(acc, "distance_metric", metric)
  end

  defp build_write_body({:schema, nil}, acc), do: acc
  defp build_write_body({:schema, schema}, acc) do
    Map.put(acc, "schema", schema)
  end

  defp build_write_body({:upsert_condition, nil}, acc), do: acc
  defp build_write_body({:upsert_condition, condition}, acc) do
    Map.put(acc, "upsert_condition", condition)
  end

  defp build_write_body({:patch_condition, nil}, acc), do: acc
  defp build_write_body({:patch_condition, condition}, acc) do
    Map.put(acc, "patch_condition", condition)
  end

  defp build_write_body({:delete_condition, nil}, acc), do: acc
  defp build_write_body({:delete_condition, condition}, acc) do
    Map.put(acc, "delete_condition", condition)
  end

  defp build_write_body({:copy_from_namespace, nil}, acc), do: acc
  defp build_write_body({:copy_from_namespace, namespace}, acc) do
    Map.put(acc, "copy_from_namespace", namespace)
  end

  defp build_write_body({:encryption, nil}, acc), do: acc
  defp build_write_body({:encryption, config}, acc) do
    Map.put(acc, "encryption", config)
  end

  # Ignore unknown options
  defp build_write_body(_, acc), do: acc

  @doc """
  Queries vectors by similarity.

  ## Options
    * `:vector` - The query vector (required)
    * `:top_k` - Number of results to return (default: 10)
    * `:include_attributes` - List of attributes to include in results, or `true` for all (default: true)
    * `:filters` - Metadata filters to apply as a map
    * `:include_vectors` - Whether to include vectors in results (default: false)
    * `:exclude_attributes` - List of attributes to exclude from results
    * `:aggregate_by` - Aggregation configuration
    * `:group_by` - Attributes to group aggregations by
    * `:vector_encoding` - Vector encoding format (:float or :base64)
    * `:consistency` - Read consistency (:strong or :eventual)

  ## Examples

      # Basic query
      Turbopuffer.Vector.query(namespace,
        vector: [0.1, 0.2, 0.3],
        top_k: 10
      )

      # Query with specific attributes and filters
      Turbopuffer.Vector.query(namespace,
        vector: [0.1, 0.2, 0.3],
        top_k: 5,
        include_attributes: ["text", "category"],
        filters: %{"category" => "doc", "public" => true}
      )

      # Include vectors in results
      Turbopuffer.Vector.query(namespace,
        vector: [0.1, 0.2, 0.3],
        top_k: 10,
        include_vectors: true
      )
  """
  @spec query(Namespace.t(), Turbopuffer.vector_query_opts()) ::
          {:ok, Turbopuffer.query_response()} | {:error, term()}
  def query(%Namespace{} = namespace, opts) do
    vector = Keyword.fetch!(opts, :vector)
    path = "/v2/namespaces/#{namespace.name}/query"

    body =
      opts
      |> build_query_body(vector)

    namespace.client
    |> Client.post(path, body)
    |> handle_query_response()
  end

  # Build query body from options using pattern matching
  defp build_query_body(opts, vector) do
    base_body = %{
      "rank_by" => ["vector", "ANN", vector],
      "top_k" => Keyword.get(opts, :top_k, 10),
      "include_attributes" => process_include_attributes(opts)
    }

    opts
    |> Enum.reduce(base_body, &add_query_option/2)
  end

  defp process_include_attributes(opts) do
    include_attributes = Keyword.get(opts, :include_attributes, true)
    include_vectors = Keyword.get(opts, :include_vectors, false)

    case {include_attributes, include_vectors} do
      {true, true} -> ["vector"]
      {true, false} -> true
      {attrs, true} when is_list(attrs) -> ["vector" | attrs] |> Enum.uniq()
      {attrs, false} -> attrs
      _ -> include_attributes
    end
  end

  # Pattern match on query options
  defp add_query_option({:vector, _}, acc), do: acc
  defp add_query_option({:top_k, _}, acc), do: acc
  defp add_query_option({:include_attributes, _}, acc), do: acc
  defp add_query_option({:include_vectors, _}, acc), do: acc

  defp add_query_option({:filters, nil}, acc), do: acc
  defp add_query_option({:filters, filters}, acc) do
    Map.put(acc, "filters", format_filters(filters))
  end

  defp add_query_option({:exclude_attributes, nil}, acc), do: acc
  defp add_query_option({:exclude_attributes, attrs}, acc) do
    Map.put(acc, "exclude_attributes", attrs)
  end

  defp add_query_option({:aggregate_by, nil}, acc), do: acc
  defp add_query_option({:aggregate_by, agg}, acc) do
    Map.put(acc, "aggregate_by", agg)
  end

  defp add_query_option({:group_by, nil}, acc), do: acc
  defp add_query_option({:group_by, groups}, acc) do
    Map.put(acc, "group_by", groups)
  end

  defp add_query_option({:vector_encoding, nil}, acc), do: acc
  defp add_query_option({:vector_encoding, encoding}, acc) do
    Map.put(acc, "vector_encoding", format_encoding(encoding))
  end

  defp add_query_option({:consistency, nil}, acc), do: acc
  defp add_query_option({:consistency, consistency}, acc) do
    Map.put(acc, "consistency", format_consistency(consistency))
  end

  defp add_query_option(_, acc), do: acc

  # Handle different response formats with pattern matching
  defp handle_query_response({:ok, %{"rows" => rows}}) when is_list(rows) do
    {:ok, Result.from_maps(rows)}
  end

  defp handle_query_response({:ok, %{"vectors" => vectors}}) when is_list(vectors) do
    {:ok, Result.from_maps(vectors)}
  end

  defp handle_query_response({:ok, %{"data" => data}}) when is_list(data) do
    {:ok, Result.from_maps(data)}
  end

  defp handle_query_response({:ok, _}) do
    {:ok, []}
  end

  defp handle_query_response(error), do: error

  # Format vectors for write operations - attributes are flattened
  defp format_write_vectors(vectors) do
    Enum.map(vectors, &format_single_vector/1)
  end

  defp format_single_vector(vector) do
    # Extract id and vector
    id = Map.get(vector, :id) || Map.get(vector, "id")
    vec = Map.get(vector, :vector) || Map.get(vector, "vector")
    attributes = Map.get(vector, :attributes) || Map.get(vector, "attributes")

    base = %{}
    base = if id, do: Map.put(base, "id", id), else: base
    base = if vec, do: Map.put(base, "vector", vec), else: base

    if attributes do
      # If attributes exist as a separate key, merge them
      Map.merge(base, attributes)
    else
      # Otherwise, all other keys are attributes
      vector
      |> Map.drop([:id, "id", :vector, "vector", :attributes, "attributes"])
      |> Map.merge(base)
    end
  end

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

  defp format_encoding(nil), do: nil
  defp format_encoding(:float), do: "float"
  defp format_encoding(:base64), do: "base64"
  defp format_encoding(other), do: other

  defp format_consistency(nil), do: nil
  defp format_consistency(:strong), do: "strong"
  defp format_consistency(:eventual), do: "eventual"
  defp format_consistency(other), do: other
end
