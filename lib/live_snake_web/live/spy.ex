defmodule LiveSnakeWeb.Spy do
  use LiveSnakeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="display:flex;align-items:center;justify-content:center;height:100vh;background:#0b1220;color:#cdd6f4;font-family:monospace">
      <div>
        <h1 style="margin:0 0 12px 0;font-size:28px;">game_1</h1>
        <p>Вы прошли через портал! 🚀</p>
        <.link navigate={~p"/"} style="color:#89b4fa;text-decoration:underline;">← вернуться</.link>
      </div>
    </div>
    """
  end
end
