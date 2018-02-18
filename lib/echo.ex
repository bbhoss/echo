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
    {:ok, chatroom} =
      socket
      |> chatroom_prompt()

    IO.puts("User joining chatroom #{chatroom}")

    case Registry.lookup(Registry.Chatrooms, chatroom) do
      [{chatroom_pid, _val} | _t] ->
        :ok = Chatroom.join(chatroom_pid, socket)

      [] ->
        {:ok, chatroom_pid} = DynamicSupervisor.start_child(ChatroomsSupervisor, Chatroom)
        :ok = Chatroom.configure(chatroom_pid, chatroom)
        Chatroom.join(chatroom_pid, socket)
    end
  end

  defp chatroom_prompt(socket) do
    write_line("What chatroom do you want to join?", socket)

    chatroom =
      read_line(socket)
      |> String.trim()

    {:ok, chatroom}
  end

  defp read_line(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end

  defp write_line(line, socket) do
    :gen_tcp.send(socket, line <> "\n")
  end
end