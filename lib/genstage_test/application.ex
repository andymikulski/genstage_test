defmodule GenstageTest.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application


  defp generate_atom_list(prefix, num) do
    Enum.map(1..num, fn n ->
      String.to_atom("#{prefix}#{n}")
    end)
  end

  defp generate_child_specs(mod, prefix, nums, subscriptions) do
    Enum.map(1..nums, fn n ->
      id = String.to_atom("#{prefix}#{n}")
      Supervisor.child_spec({mod, {id, subscriptions}}, id: id)
    end)
  end

  @impl true
  def start(_type, _args) do

    # CONFIG SETTINGS DETERMINE HOW MANY STAGE NODES TO SPIN UP
    numBStages = 4
    numCStages = 8
    numDStages = 2


    # ----
    bList = generate_atom_list("b", numBStages)
    cList = generate_atom_list("c", numCStages)

    children = [
      # Start the Ecto repository
      GenstageTest.Repo,
      # Start the Telemetry supervisor
      GenstageTestWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: GenstageTest.PubSub},
      # Start the Endpoint (http/https)
      GenstageTestWeb.Endpoint,
      # Start a worker by calling: GenstageTest.Worker.start_link(arg)
      # {GenstageTest.Worker, arg}
      {A, 0}
    ]
    ++ generate_child_specs(B, "b", numBStages, [A])
    ++ generate_child_specs(C, "c", numCStages, bList)
    ++ generate_child_specs(D, "d", numDStages, cList)



    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GenstageTest.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GenstageTestWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
