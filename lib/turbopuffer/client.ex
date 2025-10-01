defmodule Turbopuffer.Client do
  @moduledoc """
  HTTP client for the Turbopuffer API using Finch.
  """

  @regions %{
    gcp_us_central1: "https://gcp-us-central1.turbopuffer.com",
    gcp_europe_west4: "https://gcp-europe-west4.turbopuffer.com",
    gcp_asia_northeast1: "https://gcp-asia-northeast1.turbopuffer.com"
  }

  defstruct [:api_key, :base_url, :finch_name]

  @type t :: %__MODULE__{
          api_key: String.t(),
          base_url: String.t(),
          finch_name: atom()
        }

  @type response :: {:ok, map()} | {:error, term()}

  @doc """
  Creates a new Turbopuffer client.

  ## Options
    * `:api_key` - Required. The API key for authentication
    * `:region` - Optional. The region to connect to (defaults to :gcp_us_central1)
    * `:base_url` - Optional. Override the base URL
    * `:finch_name` - Optional. The name of the Finch pool (defaults to Turbopuffer.Finch)
  """
  @spec new(Turbopuffer.client_opts()) :: t()
  def new(opts) do
    api_key = Keyword.get(opts, :api_key) || System.get_env("TURBOPUFFER_API_KEY")

    if is_nil(api_key) do
      raise ArgumentError,
            "API key is required. Pass :api_key option or set TURBOPUFFER_API_KEY environment variable"
    end

    region = Keyword.get(opts, :region, :gcp_us_central1)
    base_url = Keyword.get(opts, :base_url, Map.fetch!(@regions, region))
    finch_name = Keyword.get(opts, :finch_name, Turbopuffer.Finch)

    %__MODULE__{
      api_key: api_key,
      base_url: base_url,
      finch_name: finch_name
    }
  end

  @doc """
  Makes an HTTP request to the Turbopuffer API.
  """
  @spec request(t(), atom(), String.t(), map() | nil, Turbopuffer.request_opts()) :: response()
  def request(client, method, path, body \\ nil, opts \\ []) do
    url = client.base_url <> path

    headers = [
      {"authorization", "Bearer #{client.api_key}"},
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]

    encoded_body = if body, do: JSON.encode!(body), else: nil

    request = Finch.build(method, url, headers, encoded_body)

    with {:ok, response} <- Finch.request(request, client.finch_name, opts),
         {:ok, decoded_body} <- decode_response(response) do
      if response.status in 200..299 do
        {:ok, decoded_body}
      else
        {:error, {:http_error, response.status, decoded_body}}
      end
    end
  end

  @doc """
  Makes a GET request to the Turbopuffer API.
  """
  @spec get(t(), String.t(), Turbopuffer.request_opts()) :: response()
  def get(client, path, opts \\ []), do: request(client, :get, path, nil, opts)

  @doc """
  Makes a POST request to the Turbopuffer API.
  """
  @spec post(t(), String.t(), map(), Turbopuffer.request_opts()) :: response()
  def post(client, path, body, opts \\ []), do: request(client, :post, path, body, opts)

  @doc """
  Makes a DELETE request to the Turbopuffer API.
  """
  @spec delete(t(), String.t(), Turbopuffer.request_opts()) :: response()
  def delete(client, path, opts \\ []), do: request(client, :delete, path, nil, opts)

  defp decode_response(%{body: ""}), do: {:ok, %{}}

  defp decode_response(%{body: body}) when is_binary(body) do
    case JSON.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} = error -> error
    end
  rescue
    _ -> {:error, :invalid_json}
  end
end
