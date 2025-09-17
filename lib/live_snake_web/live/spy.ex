defmodule LiveSnakeWeb.Spy do
  use LiveSnakeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, show_modal: false, player_name: "")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="spy-container">

      <!-- Кнопка -->
      <button class="players-btn" phx-click="toggle_modal">
        Игроки
      </button>

      <!-- Модалка -->
      <%= if @show_modal do %>
        <div class="modal-backdrop">
          <div class="modal-window">
            <h2>Добавить игрока</h2>
            <form phx-submit="add_player">
              <input type="text"
                     name="player_name"
                     value={@player_name}
                     placeholder="Введите имя игрока"
                     class="input-player" />
              <button type="submit" class="add-btn">Добавить</button>
              <button type="button" phx-click="toggle_modal" class="close-btn">Закрыть</button>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_modal", _params, socket) do
    {:noreply, update(socket, :show_modal, fn show -> !show end)}
  end

  @impl true
  def handle_event("add_player", %{"player_name" => name}, socket) do
    IO.puts("Добавлен игрок: #{name}")
    {:noreply, assign(socket, show_modal: false, player_name: "")}
  end

  @impl true
  def handle_event("add_spy", %{"player_name" => name}, socket) do
    IO.puts("Добавлен шпион: #{name}")
    {:noreply, assign(socket, show_modal: false, player_name: "")}
  end
end
