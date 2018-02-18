defmodule Echo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised

    children = [
      {Registry, keys: :unique, name: Registry.Chatrooms},
      ChatroomCache,
      {Task.Supervisor, name: Echo.EchoServerSupervisor},
      {DynamicSupervisor, name: ChatroomsSupervisor, strategy: :one_for_one},
      {Task, fn -> Echo.accept(4040) end}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Echo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end