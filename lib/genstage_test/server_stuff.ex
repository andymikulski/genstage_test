defmodule A do
  use GenStage

  defstruct data: [], backlog_demand: 0, start_time: 0, incoming_count: 0

  def start_link(init) do
    GenStage.start_link(__MODULE__, init, name: __MODULE__)
  end

  @impl true
  def init(_init) do
    Process.send_after(self(), :tick, 1000)
    {:producer, %__MODULE__{ data: [], backlog_demand: 0, incoming_count: 0, start_time: System.monotonic_time(:second) }}
  end

  @impl true
  def handle_demand(incoming_demand, state) when incoming_demand > 0 do
    #  IO.puts "\tA demand: #{incoming_demand}"
    # Process.sleep(1000)

    send_demanded(state, incoming_demand)
  end

  defp send_demanded(state, incoming_demand \\ 0) do
    total_demand = state.backlog_demand + incoming_demand

    {data_to_send, remaining_data} = Enum.split(state.data, total_demand)

    fulfilled_demand = Enum.count(data_to_send)
    leftover_demand = total_demand - fulfilled_demand

    remaining = Enum.count(remaining_data)
    if remaining > 0 do
      IO.puts "\n--- WARNING!!! BACKLOG!!! #{remaining} ---\n"
    end

    # if fulfilled_demand > 0 do
      # IO.puts "A fulfilling demand: #{fulfilled_demand} / #{total_demand} (#{Enum.count(remaining_data)} backlogged events)"
    # end

    {:noreply, data_to_send,
     state
     |> Map.put(:data, remaining_data)
     |> Map.put(:backlog_demand, leftover_demand)
    }
  end

  @impl true
  def handle_info(:tick, state) do
    Process.send_after(self(), :tick, 1000)
    state = state |> fake_receive_events
    send_demanded(state)
  end

  defp fake_receive_events(state) do
    upper_limit = 1000 #Enum.random(100..200)
    fake_set = Enum.to_list(1..upper_limit)

    elapsed = System.monotonic_time(:second) - state.start_time
    next_count = state.incoming_count + Enum.count(fake_set)
    IO.puts "A received #{Enum.count(fake_set)} events with #{state.backlog_demand} in demand (#{next_count / elapsed}/s)"

    next_set = fake_set ++ state.data
    state
    |> Map.put(:incoming_count, next_count)
    |> Map.put(:data, next_set)
  end

end

defmodule B do
  use GenStage

  def start_link(init = {name, _}) do
    GenStage.start_link(__MODULE__, init, name: name)
  end

  @impl true
  def init({name, targets}) do
    IO.puts "INIT B - #{name}"
    {:producer_consumer, {name}, subscribe_to: targets}
  end

  @impl true
  def handle_events(events, _from, {name}) do
    IO.puts "#{name} B events: #{Enum.count(events)}"
    Process.sleep(Enum.random(100..1000))
    # Enum.map(events, fn _ ->
    #   Process.sleep(Enum.random(20..100))
    # end)
    # events = Enum.map(events, & &1 * multiplier)
    {:noreply, events, {name}}
  end

end



defmodule C do
  use GenStage

  def start_link(init = {name, _}) do
    GenStage.start_link(__MODULE__, init, name: name)
  end

  @impl true
  def init({name, targets}) do
    IO.puts "INIT C - #{name}"

    {:producer_consumer, {name}, subscribe_to: targets}
  end

  @impl true
  def handle_events(events, _from, {name}) do
    IO.puts "#{name} C events: #{Enum.count(events)}"
    Process.sleep(Enum.random(100..1000))

    # Simulate work/db call/etc
    # Enum.map(events, fn _ ->
    #   Process.sleep(Enum.random(20..100))
    # end)

    # events = Enum.map(events, & &1 * multiplier)
    {:noreply, events, {name}}
  end
end



defmodule D do
  use GenStage

  def start_link(init = {name, _targets}) do
    GenStage.start_link(__MODULE__, init, name: name)
  end

  @impl true
  def init({name, targets}) do
    IO.puts "INIT D - #{name}"
    {:consumer, {name, System.monotonic_time(:second), 0}, subscribe_to: targets}
  end

  @impl true
  def handle_events(events, _from, {name, start_time, count}) do
    # Emit pubsub event
    Enum.map(events, fn evt ->
      Phoenix.PubSub.broadcast(GenstageTest.PubSub, "post:#{evt}", {:post_update, evt, 12345})
    end)

    elapsed = (System.monotonic_time(:second) - start_time)
    next_count = count + Enum.count(events)
    dps = next_count / elapsed

    IO.puts "------------------ #{name} D dispatched #{Enum.count(events)} events (#{dps}/s) ------------------"

    # Inspect the events.

    # We are a consumer, so we would never emit items.
    {:noreply, [], {name, start_time, next_count}}
  end
end
