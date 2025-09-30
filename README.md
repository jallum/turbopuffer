# Turbopuffer Elixir Client

An Elixir client library for the [Turbopuffer](https://turbopuffer.com) vector database API.

## Features

- Vector similarity search with cosine distance
- Full-text search with BM25 ranking
- Hybrid search combining vector and text
- Namespace management
- Built with Finch for efficient HTTP connection pooling
- Native JSON support (Elixir 1.18+)

## Installation

Add `turbopuffer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:turbopuffer, "~> 0.1.0"}
  ]
end
```

## Configuration

Set your API key as an environment variable:

```bash
export TURBOPUFFER_API_KEY="your-api-key"
```

Or pass it directly when creating a client:

```elixir
client = Turbopuffer.new(api_key: "your-api-key")
```

## Quick Start

```elixir
# Create a client
client = Turbopuffer.new(api_key: "your-api-key")

# Get or create a namespace
{:ok, namespace} = Turbopuffer.namespace(client, "my-namespace")

# Configure namespace with schema for full-text search
{:ok, _} = Turbopuffer.create_namespace(namespace,
  schema: %{
    "content" => %{"type" => "string", "full_text_search" => true}
  }
)

# Upsert vectors
vectors = [
  %{
    id: "doc1",
    vector: [0.1, 0.2, 0.3],
    attributes: %{
      content: "Introduction to machine learning",
      category: "tutorial"
    }
  },
  %{
    id: "doc2",
    vector: [0.2, 0.3, 0.4],
    attributes: %{
      content: "Deep learning fundamentals",
      category: "tutorial"
    }
  }
]

{:ok, _} = Turbopuffer.upsert(namespace, vectors)

# Query by vector similarity
{:ok, results} = Turbopuffer.query(namespace,
  vector: [0.15, 0.25, 0.35],
  top_k: 5
)

# Full-text search
{:ok, results} = Turbopuffer.text_search(namespace,
  query: "machine learning",
  attribute: "content",
  top_k: 10
)

# Hybrid search (vector + text)
{:ok, results} = Turbopuffer.hybrid_search(namespace,
  vector: [0.15, 0.25, 0.35],
  text_query: "deep learning",
  text_attribute: "content",
  top_k: 10
)
```

## API Reference

### Client Creation

```elixir
client = Turbopuffer.new(
  api_key: "your-key",
  region: :gcp_us_central1  # or :gcp_europe_west4, :gcp_asia_northeast1
)
```

### Namespace Operations

```elixir
# Create/get namespace reference
{:ok, namespace} = Turbopuffer.namespace(client, "namespace-name")

# List all namespaces
{:ok, namespaces} = Turbopuffer.list_namespaces(client)

# Get namespace statistics
{:ok, stats} = Turbopuffer.namespace_stats(namespace)

# Delete namespace
{:ok, _} = Turbopuffer.delete_namespace(namespace)
```

### Vector Operations

```elixir
# Upsert vectors
vectors = [
  %{id: "1", vector: [0.1, 0.2], attributes: %{text: "content"}}
]
{:ok, _} = Turbopuffer.upsert(namespace, vectors)

# Query vectors
{:ok, results} = Turbopuffer.query(namespace,
  vector: [0.1, 0.2],
  top_k: 10,
  include_attributes: ["text"],
  filters: %{"category" => "tutorial"}
)

# Get vectors by ID
{:ok, vectors} = Turbopuffer.get_vectors(namespace, ["doc1", "doc2"])

# Delete vectors
{:ok, _} = Turbopuffer.delete_vectors(namespace, ["doc1", "doc2"])
```

### Search Operations

```elixir
# Text search
{:ok, results} = Turbopuffer.text_search(namespace,
  query: "search terms",
  attribute: "content",
  top_k: 20
)

# Hybrid search
{:ok, results} = Turbopuffer.hybrid_search(namespace,
  vector: [0.1, 0.2],
  text_query: "search terms",
  text_attribute: "content",
  top_k: 20
)

# Multi-query with custom ranking
queries = [
  %{rank_by: [:vector, :ann, [0.1, 0.2]], top_k: 10},
  %{rank_by: ["content", "BM25", "search terms"], top_k: 10}
]

{:ok, results} = Turbopuffer.multi_query(namespace,
  queries: queries,
  top_k: 20
)
```

## Advanced Usage

### Custom Finch Configuration

You can customize the Finch connection pool in your application:

```elixir
# In your application.ex
children = [
  {Finch,
   name: MyApp.TurbopufferFinch,
   pools: %{
     "https://gcp-us-central1.turbopuffer.com" => [
       size: 20,
       count: 4,
       conn_opts: [timeout: 30_000]
     ]
   }}
]

# Use custom Finch name
client = Turbopuffer.new(
  api_key: "your-key",
  finch_name: MyApp.TurbopufferFinch
)
```

### Error Handling

All operations return `{:ok, result}` or `{:error, reason}`:

```elixir
case Turbopuffer.query(namespace, vector: [0.1, 0.2]) do
  {:ok, results} ->
    # Process results
    IO.inspect(results)

  {:error, {:http_error, status, body}} ->
    # Handle HTTP error
    IO.puts("HTTP error #{status}: #{inspect(body)}")

  {:error, reason} ->
    # Handle other errors
    IO.puts("Error: #{inspect(reason)}")
end
```

## Testing

Run the test suite:

```bash
mix test
```

For integration tests with a real Turbopuffer instance:

```bash
TURBOPUFFER_API_KEY="your-test-key" mix test --include integration
```

## License

MIT

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Links

- [Turbopuffer Documentation](https://turbopuffer.com/docs)
- [API Reference](https://turbopuffer.com/docs/reference)
- [Hex Package](https://hex.pm/packages/turbopuffer)

