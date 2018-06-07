use Amnesia
alias :mnesia, as: Mnesia

defdatabase Persiqueue.Database do
  deftable Message

  deftable Message, [{:id, autoincrement}, :content, :ack, :head, :next, :previous], type: :set do
    @type t :: %Message{id: non_neg_integer(), content: term(), ack: boolean(), head: boolean(),
                        next: non_neg_integer(), previous: non_neg_integer()}

    ## Public Interface

    def add(message) do
      fn ->
        case fetch_last() do
          nil ->
            new = Message.write(%Message{
                content: message, ack: true, head: true, next: nil, previous: nil})

            {:ok, new}
          last ->
            new = Message.write(%Message{
                content: message, ack: true, head: (last.ack == false), next: last.id, previous: nil})
            Message.write(%{last | previous: new.id})

            {:ok, new}
        end
      end
      |> Amnesia.transaction!
    end

    def get do
      fn ->
        case fetch_head() do
          nil ->
            {:error, :empty_queue}
          head ->
            unless is_nil head.previous do
              previous = Message.read(head.previous)
              Message.write(%{previous | head: true})
            end
            Message.write(%{head | ack: false, head: false})

            {:ok, head}
        end
      end
      |> Amnesia.transaction!
    end

    def ack do
      fn ->
        case fetch_first() do
          nil ->
            {:error, :empty_queue}
          first ->
            case first.head do
              true ->
                {:error, :all_acknowledged}
              false ->
                unless is_nil first.previous do
                  previous = Message.read(first.previous)
                  Message.write(%{previous | next: nil})
                end
                Message.delete(first)

                {:ok, first}
            end
        end
      end
      |> Amnesia.transaction!
    end

    def reject do
      fn ->
        case fetch_first() do
          nil ->
            {:error, :empty_queue}
          first ->
            case first.head do
              true ->
                {:error, :all_acknowledged}
              false ->
                unless is_nil first.previous do
                  previous = Message.read(first.previous)
                  Message.write(%{previous | next: nil})
                end
                last = fetch_last()
                case last == first do
                  true ->
                    Message.write(%{first | ack: true, head: true})
                  false ->
                    Message.write(%{last | previous: first.id,
                                    next: (if last.next == first.id, do: nil, else: last.next)})
                    Message.write(%{first | previous: nil,
                                    next: last.id, ack: true, head: (last.ack == false)})
                end

                {:ok, first}
            end
        end
      end
      |> Amnesia.transaction!
    end

    def all do
      fn -> fetch_all() end
      |> Amnesia.transaction!
    end

    ## Auxiliary Functions

    ## TODO: use Amnesia possibilities to select data

    defp fetch_all do
      Mnesia.select(Message, [{match(), [guard_all_ids()], result()}])
      |> Enum.map(&pack/1)
    end

    defp fetch_first do
      case Mnesia.select(Message, [{match(), [guard_next(nil)], result()}]) do
        []      -> nil
        [first] -> first |> pack
      end
    end

    defp fetch_last do
      case Mnesia.select(Message, [{match(), [guard_previous(nil)], result()}]) do
        []     -> nil
        [last] -> last |> pack
      end
    end

    defp fetch_head do
      case Mnesia.select(Message, [{match(), [guard_head(true)], result()}]) do
        []     -> nil
        [head] -> head |> pack
      end
    end

    defp pack([id, content, ack, head, next, previous]) do
      %Message{id: id, content: content, ack: ack, head: head, next: next, previous: previous}
    end

    defp match,                    do: {Message, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6"}
    defp guard_all_ids,            do: {:>, :"$1", 0}
    defp guard_head(head),         do: {:==, :"$4", head}
    defp guard_next(next),         do: {:==, :"$5", next}
    defp guard_previous(previous), do: {:==, :"$6", previous}
    defp result,                   do: [:"$$"]
  end
end
