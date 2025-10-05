defmodule LiveSnakeWeb.Spy do
  use LiveSnakeWeb, :live_view

  @min_players 3
  @max_players 12

  @impl true
  def mount(_params, _session, socket) do
    players =
      1..5
      |> Enum.map(fn _ -> %{id: gen_id(), name: ""} end)

    {:ok,
     assign(socket,
       show_modal: false,
       players: players,
       count: length(players),
       flash_msg: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="spy-container">
      <!-- Кнопка открытия -->
      <button class="players-btn" phx-click="toggle_modal">Игроки</button>

      <!-- Модалка -->
      <%= if @show_modal do %>
        <div class="modal-backdrop" phx-window-keydown="esc" phx-key="escape">
          <div class="modal-window">
            <div class="modal-header items-center justify-between" style="text-align: center">
              <h2>Игроков</h2>
            </div>

            <!-- Счётчик -->
            <div class="counter-row">
              <button class="counter-btn" phx-click="dec">−</button>
              <span class="counter-value"><%= @count %></span>
              <button class="counter-btn" phx-click="inc">+</button>
            </div>

            <!-- Форма имён -->
            <form phx-change="change_players" phx-submit="save_players" autocomplete="off">
              <div class="players-list">
                <%= for p <- @players do %>
                  <div class="player-row">
                    <div class="avatar">🧑</div>
                    <input
                      type="text"
                      class="input-player grow"
                      name={"players[#{p.id}][name]"}
                      value={p.name}
                      placeholder="Имя"
                    />
                    <button type="button"
                            class="trash-btn"
                            phx-click="remove_player"
                            phx-value-id={p.id}
                            title="Удалить">
                      🗑
                    </button>
                  </div>
                <% end %>
              </div>

              <div class="mt-4">
                <button type="submit" class="spy-ok-button">Сохранить</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_modal", _params, socket) do
    {:noreply, update(socket, :show_modal, &(!&1))}
  end

  @impl true
  def handle_event("inc", _params, %{assigns: %{count: c}} = socket) when c < @max_players do
    {:noreply, socket |> add_blank_player() |> update_count()}
  end

  def handle_event("inc", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("dec", _params, %{assigns: %{count: c}} = socket) when c > @min_players do
    {:noreply, socket |> drop_last_player() |> update_count()}
  end

  def handle_event("dec", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("remove_player", %{"id" => id_str}, socket) do
    id = parse_id(id_str)

    players =
      socket.assigns.players
      |> Enum.reject(&(&1.id == id))
      |> ensure_min(@min_players)

    {:noreply, assign(socket, players: players, count: length(players))}
  end

  @impl true
  def handle_event("change_players", %{"players" => incoming}, socket) do
    incoming_map =
      for {id_str, %{"name" => name}} <- incoming, into: %{} do
        {parse_id(id_str), name}
      end

    players =
      Enum.map(socket.assigns.players, fn p ->
        case Map.fetch(incoming_map, p.id) do
          {:ok, name} -> %{p | name: name}
          :error -> p
        end
      end)

    {:noreply, assign(socket, players: players)}
  end

  @impl true
  def handle_event("save_players", _params, socket) do
    names =
      socket.assigns.players
      |> Enum.map(&String.trim(&1.name))
      |> Enum.reject(&(&1 == ""))

    IO.inspect(names, label: "Сохранён список игроков")

    {:noreply,
     socket
     |> put_flash(:info, "Игроки сохранены (#{length(names)})")
     |> assign(show_modal: false)}
  end

  # --- helpers ---

  defp add_blank_player(%{assigns: %{players: ps}} = socket) do
    assign(socket, players: ps ++ [%{id: gen_id(), name: ""}])
  end

  defp drop_last_player(%{assigns: %{players: ps}} = socket) do
    assign(socket, players: Enum.drop(ps, -1))
  end

  defp update_count(%{assigns: %{players: ps}} = socket),
    do: assign(socket, count: length(ps))

  defp ensure_min(list, min) do
    need = max(0, min - length(list))
    list ++ Enum.map(1..need, fn _ -> %{id: gen_id(), name: ""} end)
  end

  defp gen_id, do: System.unique_integer([:positive])
  defp parse_id(id) when is_integer(id), do: id
  defp parse_id(id) when is_binary(id), do: String.to_integer(id)
end
