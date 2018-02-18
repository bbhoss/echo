require Logger

defmodule Echo do
  def start_link do
  end

  def accept(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    Logger.info("Accepting connections on #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} =
      Task.Supervisor.start_child(Echo.EchoServerSupervisor, fn ->
        serve(client)
      end)

    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(socket) do
    {:ok, username} =
      socket
      |> prompt("What's your name?")

    {:ok, chatroom} =
      socket
      |> list_chatrooms()
      |> prompt("What chatroom do you want to join?")

    IO.puts("User joining chatroom #{chatroom}")

    case Registry.lookup(Registry.Chatrooms, chatroom) do
      [{chatroom_pid, _val} | _t] ->
        :ok = Chatroom.join(chatroom_pid, socket, username)

      [] ->
        {:ok, chatroom_pid} = DynamicSupervisor.start_child(ChatroomsSupervisor, Chatroom)
        :ok = Chatroom.configure(chatroom_pid, chatroom)
        Chatroom.join(chatroom_pid, socket, username)
    end
  end

  defp list_chatrooms(socket) do
    write_line("Current Rooms:", socket)

    for room <- ChatroomCache.list_rooms() do
      write_line(room, socket)
    end

    socket
  end

  defp prompt(socket, message) do
    write_line(message, socket)

    result =
      read_line(socket)
      |> String.trim()

    {:ok, result}
  end

  defp read_line(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end

  defp write_line(line, socket) do
    :gen_tcp.send(socket, line <> "\n")
  end
end