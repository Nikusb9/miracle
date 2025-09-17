defmodule LiveSnakeWeb.PageLive do
  use LiveSnakeWeb, :live_view

  alias LiveSnake.Game.Loop
  alias Phoenix.PubSub

  @player_size 20
  @ground_y 95

  # Параметры портала (константы модуля)
  @portal_x 700          # X левого края портала
  @portal_w 32           # ширина портала
  @portal_h @ground_y    # высота портала = высоте платформы
  @portal_touch_pad 12   # допуск по X, чтобы легче попасть

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
       ground_y: @ground_y,
       # ВАЖНО: прокидываем портал в assigns, чтобы @portal_* были видны в HEEx
       portal_x: @portal_x,
       portal_w: @portal_w,
       portal_h: @portal_h,
       portal_pad: @portal_touch_pad
     )}
  end

  # ---------------- Клавиатура ----------------

  @impl true
  def handle_event("keydown", %{"key" => key}, socket) do
    cond do
      key in ["a", "A", "ф", "Ф"] ->
        Loop.handle_input(socket.assigns.player_id, :left, true)
        {:noreply, socket}

      key in ["d", "D", "в", "В"] ->
        Loop.handle_input(socket.assigns.player_id, :right, true)
        {:noreply, socket}

      # прыжок/портал
      key in [" ", "w", "W", "ц", "Ц", "ArrowUp"] ->
        maybe_portal_or_jump(socket)

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("keyup", %{"key" => key}, socket) do
    cond do
      key in ["a", "A", "ф", "Ф"] ->
        Loop.handle_input(socket.assigns.player_id, :left, false)
        {:noreply, socket}

      key in ["d", "D", "в", "В"] ->
        Loop.handle_input(socket.assigns.player_id, :right, false)
        {:noreply, socket}

      key in [" ", "w", "W", "ц", "Ц", "ArrowUp"] ->
        Loop.handle_input(socket.assigns.player_id, :jump, false)
        {:noreply, socket}

      true ->
        {:noreply, socket}
    end
  end

  # Прыжок рядом с порталом → навигация; иначе обычный прыжок
  defp maybe_portal_or_jump(socket) do
    if near_portal?(socket) do
      {:noreply, push_navigate(socket, to: ~p"/game_1")}
    else
      Loop.handle_input(socket.assigns.player_id, :jump, true)
      {:noreply, socket}
    end
  end

  defp near_portal?(socket) do
    with %{} = self <- socket.assigns.players[socket.assigns.player_id] do
      px = self.x
      py = self.y

      px >= socket.assigns.portal_x - socket.assigns.portal_pad and
      px <= socket.assigns.portal_x + socket.assigns.portal_w + socket.assigns.portal_pad and
      py == socket.assigns.ground_y
    else
      _ -> false
    end
  end

  # --------------- Сообщения от движка ---------------

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

  # -------------------- Рендер -----------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div id="world"
         phx-window-keydown="keydown"
         phx-window-keyup="keyup"
         style="position: relative; width: 800px; height: 600px;">

      <!-- Платформа (сзади) -->
      <div class="platform"
           style={"position:absolute; left:0; bottom:0; width:100%; height: #{@ground_y}px; z-index:0;"}></div>

      <!-- Портал -->
      <div id="portal"
           style={"position:absolute; bottom:#{@ground_y}px; left: #{@portal_x}px;
                   width: #{@portal_w}px; height: #{@portal_h}px;
                   background: linear-gradient(180deg, #94e2d5, #89b4fa);
                   box-shadow: 0 0 8px #89b4fa, inset 0 0 6px #94e2d5;
                   border: 1px solid #b4bef7;
                   opacity: 0.9; z-index:1;"}></div>

      <!-- Игроки (поверх всего) -->
      <%= for {player_id, player} <- @players do %>
        <div id={player_id}
             class="player"
             style={"position:absolute; left: #{player.x}px; bottom: #{@ground_y}px;
                     width: #{@player_size}px; height: #{@player_size}px;
                     transform: translateY(#{player.y - @ground_y}px);
                     z-index:10;"} />
      <% end %>
    </div>
    """
  end
end

