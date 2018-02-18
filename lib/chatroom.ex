defmodule Chatroom do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(_args) do
    {:ok, {}}
  end

  def handle_call({:configure, chatroom}, _ref, _state) do
    {:ok, _pid} = Registry.register(Registry.Chatrooms, chatroom, self())
    {:reply, :ok, {chatroom, []}}
  end

  def handle_call({:join, client}, _ref, {chatroom, sockets}) do
    :ok = configure_socket(client)
    IO.puts("Socket joined chatroom #{chatroom}")
    {:reply, :ok, {chatroom, [client | sockets]}}
  end

  defp configure_socket(socket) do
    :ok = :inet.setopts(socket, active: :once)
    :ok
  end

  def handle_info({:tcp, client, message}, state = {_, sockets}) do
    for sock <- sockets, sock != client do
      writeln(sock, String.trim(message))
    end

    # Queue messages from client in kernel buffer until they've been relayed to other users
    :ok = configure_socket(client)
    {:noreply, state}
  end

  defp writeln(socket, line) do
    :gen_tcp.send(socket, line <> "\n")
  end

  def join(chatroom, socket) do
    :ok = :gen_tcp.controlling_process(socket, chatroom)
    GenServer.call(chatroom, {:join, socket})
  end

  def configure(pid, chatroom) do
    GenServer.call(pid, {:configure, chatroom})
  end
end