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
  Deletes a namespace.

  ## Examples

      {:ok, _} = Turbopuffer.Namespace.delete(namespace)
  """
  @spec delete(t()) :: {:ok, map()} | {:error, term()}
  def delete(%__MODULE__{} = namespace) do
    path = "/v2/namespaces/#{namespace.name}"
    Client.delete(namespace.client, path)
  end
end
