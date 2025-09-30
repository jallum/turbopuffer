defmodule Turbopuffer.Namespace do
  @moduledoc """
  Handles namespace operations for Turbopuffer.
  """

  alias Turbopuffer.Client

  defstruct [:client, :name]

  @type t :: %__MODULE__{
          client: Client.t(),
          name: String.t()
        }

  @doc """
  Creates a namespace reference.
  """
  @spec new(Client.t(), String.t()) :: t()
  def new(client, name) do
    %__MODULE__{
      client: client,
      name: name
    }
  end

  @doc """
  Creates or configures a namespace with optional schema.

  ## Options
    * `:distance_metric` - The distance metric to use (e.g., "cosine_distance")
    * `:schema` - Schema configuration for the namespace
  """
  @spec create(t(), keyword()) :: {:ok, map()} | {:error, term()}
  def create(%__MODULE__{} = namespace, opts \\ []) do
    body = build_schema_body(opts)
    path = "/v2/namespaces/#{namespace.name}"
    Client.post(namespace.client, path, body)
  end

  @doc """
  Deletes a namespace.
  """
  @spec delete(t()) :: {:ok, map()} | {:error, term()}
  def delete(%__MODULE__{} = namespace) do
    path = "/v2/namespaces/#{namespace.name}"
    Client.delete(namespace.client, path)
  end

  @doc """
  Lists all namespaces.
  """
  @spec list(Client.t()) :: {:ok, list(String.t())} | {:error, term()}
  def list(client) do
    path = "/v2/namespaces"

    case Client.get(client, path) do
      {:ok, %{"namespaces" => namespaces}} -> {:ok, namespaces}
      {:ok, response} -> {:ok, response}
      error -> error
    end
  end

  @doc """
  Gets namespace statistics.
  """
  @spec stats(t()) :: {:ok, map()} | {:error, term()}
  def stats(%__MODULE__{} = namespace) do
    path = "/v2/namespaces/#{namespace.name}/stats"
    Client.get(namespace.client, path)
  end

  defp build_schema_body(opts) do
    schema = Keyword.get(opts, :schema, %{})
    distance_metric = Keyword.get(opts, :distance_metric, "cosine_distance")

    %{
      "distance_metric" => distance_metric,
      "schema" => schema
    }
  end
end