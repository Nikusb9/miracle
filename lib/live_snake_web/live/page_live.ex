defmodule LiveSnakeWeb.PageLive do
  use LiveSnakeWeb, :live_view

  alias LiveSnake.Game.Loop
  alias Phoenix.PubSub

  @player_size 20
  @ground_y 95

  @impl true
  def mount(_params, _session, socket) do
    PubSub.subscribe(LiveSnake.PubSub, "players")
    player_id = "player-#{System.unique_integer([:positive])}"
    Loop.add_player(self(), player_id)

    {:ok,
     assign(socket,
       player_id: player_id,
       players: %{},
       player_size: @player_size,
       # ← прокинули в assigns
       ground_y: @ground_y
     )}
  end

  @impl true
  def handle_event("keydown", %{"key" => key}, socket) do
    case key do
      "a" -> Loop.handle_input(socket.assigns.player_id, :left, true)
      "d" -> Loop.handle_input(socket.assigns.player_id, :right, true)
      " " -> Loop.handle_input(socket.assigns.player_id, :jump, true)
      "w" -> Loop.handle_input(socket.assigns.player_id, :jump, true)
      "W" -> Loop.handle_input(socket.assigns.player_id, :jump, true)
      "ц" -> Loop.handle_input(socket.assigns.player_id, :jump, true)
      "Ц" -> Loop.handle_input(socket.assigns.player_id, :jump, true)
      "ArrowUp" -> Loop.handle_input(socket.assigns.player_id, :jump, true)
      _ -> :ok
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("keyup", %{"key" => key}, socket) do
    case key do
      "a" -> Loop.handle_input(socket.assigns.player_id, :left, false)
      "d" -> Loop.handle_input(socket.assigns.player_id, :right, false)
      " " -> Loop.handle_input(socket.assigns.player_id, :jump, false)
      "w" -> Loop.handle_input(socket.assigns.player_id, :jump, false)
      "W" -> Loop.handle_input(socket.assigns.player_id, :jump, false)
      "ц" -> Loop.handle_input(socket.assigns.player_id, :jump, false)
      "Ц" -> Loop.handle_input(socket.assigns.player_id, :jump, false)
      "ArrowUp" -> Loop.handle_input(socket.assigns.player_id, :jump, false)
      _ -> :ok
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:world_update, %{pts: pts}}, socket) do
    mapped = for {id, {x, y}} <- pts, into: %{}, do: {id, %{x: x, y: y}}
    {:noreply, update(socket, :players, &Map.merge(&1, mapped))}
  end

  @impl true
  def handle_info({:despawn, ids}, socket) do
    updated = Enum.reduce(ids, socket.assigns.players, fn id, acc -> Map.delete(acc, id) end)
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
    <div
      id="world"
      phx-window-keydown="keydown"
      phx-window-keyup="keyup"
      style="position: relative; width: 800px; height: 600px;"
    >
      <%= for {player_id, player} <- @players do %>
        <div
          id={player_id}
          class="player"
          style={"position: absolute; left: #{player.x}px; bottom: 95px;
                  width: #{@player_size}px; height: #{@player_size}px;
                  transform: translateY(#{player.y - @ground_y}px);"}
        />
      <% end %>

      <div class="platform"
           style={"position:absolute; left:0; bottom:0; width:100%; height: #{@ground_y}px;"}></div>
    </div>
    """
  end
end
