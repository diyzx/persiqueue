defmodule Persiqueue do
  use Application

  def start(_, _) do
    {:ok, _} = Application.ensure_all_started(:libcluster)

    children = [
      Persiqueue.Queue
    ]
    opts = [strategy: :one_for_one, name: Persiqueue.Supervisor]

    Supervisor.start_link(children, opts)
  end

  def current_nodes, do: [Node.self() | Node.list()] |> Enum.sort
  def all_nodes, do: Application.get_env(:libcluster, :topologies)[:epmd][:config][:hosts] |> Enum.sort
end
