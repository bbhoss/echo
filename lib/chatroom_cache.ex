defmodule ChatroomCache do
  use Agent

  @name Agent.ChatroomCache

  def start_link(_args) do
    Agent.start_link(fn -> [] end, name: @name)
  end

  def list_rooms() do
    Agent.get(@name, & &1)
  end

  def register_room(chatroom_name) do
    Agent.update(@name, &[chatroom_name | &1])
  end
end