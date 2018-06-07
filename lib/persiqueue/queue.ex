defmodule Persiqueue.Queue do
  use GenServer
  use Persiqueue.Database
  alias Persiqueue.Database.Message
  require Logger

  ## Public Interface

  # Add Message in the end of the Queue
  def add(message) do
    process_response Message.add(message)
  end

  # Get the next Message from the beginning of the Queue for processing
  def get do
    process_response Message.get
  end

  # Acknowledge successful processing of the Message
  def ack do
    process_response Message.ack
  end

  # Reject processing of the Message and add the Message back in the end of the Queue
  def reject do
    process_response Message.reject
  end

  defp process_response(response) do
    case response do
      {:ok, message} -> {:ok, message.content}
      {:error, _}    -> response
      :badarg        -> {:error, :inconsistent_node}
    end
  end

  ## Auxiliary Functions

  # Show current state of the Queue
  def show(debug \\ false) do
    all = Message.all()
    case all do
      :badarg ->
        {:error, :inconsistent_node}
      _ ->
        queue =
          case all |> Enum.filter(&(is_nil &1.previous)) do
            []     -> []
            [head] -> show([head | (all -- [head])], [])
          end
        case debug do
          true  -> {:ok, queue}
          false -> {:ok, queue |> Enum.map(&({&1.content, &1.ack}))}
        end

    end
  end
  defp show([], acc), do: acc
  defp show([head | []], acc), do: show([], [head | acc])
  defp show([head | tail], acc) do
    [new_head] = tail |> Enum.filter(&(&1.previous == head.id))
    show([new_head | (tail -- [new_head])], [head | acc])
  end

  ## Callback Functions

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: :"persiqueue_#{Node.self()}")
  end

  # Ensure all predefined Queue's nodes are running
  def init(args) do
    case Persiqueue.current_nodes() == Persiqueue.all_nodes() do
      false ->
        absent_nodes = Persiqueue.all_nodes() -- Persiqueue.current_nodes()
        Logger.debug "Queue is waiting for #{inspect absent_nodes}"
        1 |> :timer.seconds |> :timer.sleep

        init(args)
      true ->
        if Node.self() == hd Persiqueue.all_nodes() do
          schema_result = Amnesia.Schema.create(Persiqueue.all_nodes())
          Logger.debug "Mnesia schema is created: #{inspect schema_result}"

          :rpc.multicall(Persiqueue.all_nodes(), Amnesia, :start, [])
          Logger.debug "Mnesia is started on #{inspect Persiqueue.all_nodes()}"

          message_table_result = Database.create(disk: Persiqueue.all_nodes())
          :ok = Database.wait()
          Logger.debug "Message table is created: #{inspect message_table_result}"
        end

        {:ok, %{}}
    end
  end
end
