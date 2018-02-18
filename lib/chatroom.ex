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
    :ok = ChatroomCache.register_room(chatroom)
    {:reply, :ok, {chatroom, %{}}}
  end

  def handle_call({:join, client, username}, _ref, {chatroom, sockets}) do
    :ok = configure_socket(client)
    bulk_send(sockets, "#{username} joined the chat")
    {:reply, :ok, {chatroom, Map.put(sockets, client, username)}}
  end

  defp configure_socket(socket) do
    :ok = :inet.setopts(socket, active: :once)
    :ok
  end

  def handle_info({:tcp, client, message}, state = {_, sockets}) do
    sender_username = Map.get(sockets, client)

    bulk_send(sockets, sender_username <> ": " <> String.trim(message))

    # Queue messages from client in kernel buffer until they've been relayed to other users
    :ok = configure_socket(client)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, client}, {chatroom, sockets}) do
    leaving_user = Map.get(sockets, client)
    bulk_send(sockets, "#{leaving_user} left the chat")
    {:noreply, {chatroom, Map.delete(sockets, client)}}
  end

  defp bulk_send(sockets, message) do
    for {sock, _username} <- sockets do
      writeln(sock, message)
    end
  end

  defp writeln(socket, line) do
    :gen_tcp.send(socket, line <> "\n")
  end

  def join(chatroom, socket, username) do
    :ok = :gen_tcp.controlling_process(socket, chatroom)
    GenServer.call(chatroom, {:join, socket, username})
  end

  def configure(pid, chatroom) do
    GenServer.call(pid, {:configure, chatroom})
  end
end