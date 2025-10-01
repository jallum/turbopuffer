defmodule Turbopuffer.Vector do
  @moduledoc """
  Handles vector operations for Turbopuffer.
  """

  alias Turbopuffer.{Client, Namespace, Result}

  @doc """
  Writes vectors to a namespace (upserts and/or deletes).

  ## Options
    * `:upsert_rows` - List of vectors to upsert
    * `:deletes` - List of IDs to delete
    * `:distance_metric` - The distance metric to use (e.g., "cosine_distance", "euclidean_squared")
    * `:schema` - Schema configuration for attributes

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

    upsert_rows = Keyword.get(opts, :upsert_rows, [])
    deletes = Keyword.get(opts, :deletes, [])

    body =
      %{}
      |> maybe_add_field(
        "upsert_rows",
        if(upsert_rows != [], do: format_write_vectors(upsert_rows))
      )
      |> maybe_add_field("deletes", if(deletes != [], do: deletes))
      |> maybe_add_field("distance_metric", Keyword.get(opts, :distance_metric))
      |> maybe_add_field("schema", Keyword.get(opts, :schema))

    Client.post(namespace.client, path, body)
  end

  @doc """
  Queries vectors by similarity.

  ## Options
    * `:vector` - The query vector (required)
    * `:top_k` - Number of results to return (default: 10)
    * `:distance_metric` - Distance metric to use (e.g., "cosine_distance", "euclidean_squared")
    * `:include_attributes` - List of attributes to include in results, or `true` for all (default: true)
    * `:filters` - Metadata filters to apply as a map
    * `:include_vectors` - Whether to include vectors in results (default: false)

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
    top_k = Keyword.get(opts, :top_k, 10)
    include_attributes = Keyword.get(opts, :include_attributes, true)
    include_vectors = Keyword.get(opts, :include_vectors, false)
    filters = Keyword.get(opts, :filters)
    distance_metric = Keyword.get(opts, :distance_metric)

    # Handle include_vectors by adding "vector" to include_attributes
    include_attrs =
      case {include_attributes, include_vectors} do
        {true, true} -> ["vector"]
        {true, false} -> true
        {attrs, true} when is_list(attrs) -> ["vector" | attrs] |> Enum.uniq()
        {attrs, false} -> attrs
        _ -> include_attributes
      end

    path = "/v2/namespaces/#{namespace.name}/query"

    body =
      %{
        "rank_by" => ["vector", "ANN", vector],
        "top_k" => top_k,
        "include_attributes" => include_attrs
      }
      |> maybe_add_field("filters", format_filters(filters))
      |> maybe_add_field("distance_metric", distance_metric)

    case Client.post(namespace.client, path, body) do
      {:ok, %{"rows" => rows}} when is_list(rows) ->
        {:ok, Result.from_maps(rows)}

      {:ok, %{"vectors" => vectors}} when is_list(vectors) ->
        {:ok, Result.from_maps(vectors)}

      {:ok, %{"data" => vectors}} when is_list(vectors) ->
        {:ok, Result.from_maps(vectors)}

      {:ok, _response} ->
        # Return empty list if no vectors found
        {:ok, []}

      error ->
        error
    end
  end

  # Format vectors for write operations - attributes are flattened
  defp format_write_vectors(vectors) do
    Enum.map(vectors, fn vector ->
      # Extract id and vector
      id = Map.get(vector, :id) || Map.get(vector, "id")
      vec = Map.get(vector, :vector) || Map.get(vector, "vector")

      # Check if attributes are nested or flat
      attributes = Map.get(vector, :attributes) || Map.get(vector, "attributes")

      result =
        %{}
        |> maybe_add_field("id", id)
        |> maybe_add_field("vector", vec)

      if attributes do
        # If attributes exist as a separate key, merge them
        Map.merge(result, attributes)
      else
        # Otherwise, all other keys are attributes
        vector
        |> Map.drop([:id, "id", :vector, "vector", :attributes, "attributes"])
        |> Map.merge(result)
      end
    end)
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
