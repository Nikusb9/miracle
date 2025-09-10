defmodule LiveSnakeWeb.PageLive do
  use LiveSnakeWeb, :live_view

  alias LiveSnake.Game.Loop
  alias Phoenix.PubSub

  @player_size 20

  @impl true
  def mount(_params, _session, socket) do
    PubSub.subscribe(LiveSnake.PubSub, "players")
    player_id = "player-#{System.unique_integer([:positive])}"
    Loop.add_player(self(), player_id)

    {:ok,
     assign(socket,
       player_id: player_id,
       players: %{},
       player_size: @player_size
     )}
  end

  @impl true
  def handle_event("keydown", %{"key" => key}, socket) do
    case key do
      "a" -> Loop.handle_input(socket.assigns.player_id, :left, true)
      "d" -> Loop.handle_input(socket.assigns.player_id, :right, true)
      _ -> :ok
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("keyup", %{"key" => key}, socket) do
    case key do
      "a" -> Loop.handle_input(socket.assigns.player_id, :left, false)
      "d" -> Loop.handle_input(socket.assigns.player_id, :right, false)
      _ -> :ok
    end

    {:noreply, socket}
  end

  # ДВИЖОК шлёт {:world_update, %{t: _, pts: %{id => {x, y}}}}
  # Конвертируем кортеж {x, y} -> %{x: x, y: y} и мержим в assigns.players
  @impl true
  def handle_info({:world_update, %{pts: pts}}, socket) do
    mapped =
      for {id, {x, y}} <- pts, into: %{} do
        {id, %{x: x, y: y}}
      end

    updated = Map.merge(socket.assigns.players, mapped)
    {:noreply, assign(socket, players: updated)}
  end

  # Удаление игроков
  @impl true
  def handle_info({:despawn, ids}, socket) do
    updated =
      Enum.reduce(ids, socket.assigns.players, fn id, acc ->
        Map.delete(acc, id)
      end)

    {:noreply, assign(socket, players: updated)}
  end

  @impl true
  def terminate(_reason, socket) do
    Loop.remove_player(socket.assigns.player_id)
    :ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="platform" phx-window-keydown="keydown" phx-window-keyup="keyup">
      <%= for {player_id, player} <- @players do %>
        <div
          id={player_id}
          class="player"
          style={"top: -20px; left: #{player.x}px;
                  width: #{@player_size}px; height: #{@player_size}px;
                  border-radius: 3px;
                  transform: translateY(#{player.y - 95}px);"}
        />
      <% end %>
    </div>
    """
  end
end
