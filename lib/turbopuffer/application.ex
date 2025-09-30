defmodule Turbopuffer.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch,
       name: Turbopuffer.Finch,
       pools: %{
         :default => [size: 10, count: 2]
       }}
    ]

    opts = [strategy: :one_for_one, name: Turbopuffer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end