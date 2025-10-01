defmodule Turbopuffer.Result do
  @moduledoc """
  Represents a single result from a query operation.
  """

  @type t :: %__MODULE__{
          id: String.t() | integer(),
          dist: float() | nil,
          attributes: map() | nil,
          vector: [float()] | nil
        }

  defstruct [:id, :dist, :attributes, :vector]

  @doc """
  Converts a raw API response map to a Result struct.

  Handles both `dist` and `$dist` field names from the API.
  Attributes are extracted as all fields except id, dist, $dist, and vector.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    # Extract known fields
    id = Map.get(map, "id")
    dist = Map.get(map, "dist") || Map.get(map, "$dist")
    vector = Map.get(map, "vector")

    # All other fields are attributes
    reserved_keys = ["id", "dist", "$dist", "vector"]

    attributes =
      map
      |> Map.drop(reserved_keys)
      |> case do
        attrs when attrs == %{} -> nil
        attrs -> attrs
      end

    %__MODULE__{
      id: id,
      dist: dist,
      attributes: attributes,
      vector: vector
    }
  end

  @doc """
  Converts a list of raw API response maps to Result structs.
  """
  @spec from_maps([map()]) :: [t()]
  def from_maps(maps) when is_list(maps) do
    Enum.map(maps, &from_map/1)
  end
end
