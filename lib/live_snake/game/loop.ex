defmodule LiveSnake.Game.Loop do
  use GenServer
  alias Phoenix.PubSub

  @tick_ms 100
  @idle_ms 200

  @gravity 0.7
  @move_speed 20
  # ↑ вверх (отрицательная vy), подбери по вкусу: 6–10
  @jump_impulse 6
  @ground_y 45
  @player_size 20
  @playground 800

  # --- API ---
  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def add_player(pid, player_id), do: GenServer.cast(__MODULE__, {:add_player, pid, player_id})
  def remove_player(player_id), do: GenServer.cast(__MODULE__, {:remove_player, player_id})

  def handle_input(player_id, input, value),
    do: GenServer.cast(__MODULE__, {:handle_input, player_id, input, value})

  # --- GenServer ---
  @impl true
  def init(_state) do
    now = System.monotonic_time(:millisecond)
    ref = Process.send_after(self(), :tick, @tick_ms)
    {:ok, %{players: %{}, tick_no: 0, next_at: now + @tick_ms, timer_ref: ref}}
  end

  @impl true
  def handle_cast({:add_player, pid, player_id}, state) do
    Process.monitor(pid)

    player = %{
      id: player_id,
      pid: pid,
      x: Enum.random(200..600),
      y: @ground_y,
      vx: 0,
      vy: 0,
      input: %{left: false, right: false, jump: false}
    }

    {:noreply, put_in(state.players[player_id], player),
     {:continue, {:spawn_broadcast, player_id, player.x, player.y}}}
  end

  @impl true
  def handle_cast({:remove_player, player_id}, state) do
    if Map.has_key?(state.players, player_id) do
      PubSub.broadcast(LiveSnake.PubSub, "players", {:despawn, [player_id]})
    end

    {:noreply, update_in(state.players, &Map.delete(&1, player_id))}
  end

  @impl true
  def handle_cast({:handle_input, player_id, input, value}, state) do
    case state.players[player_id] do
      nil ->
        {:noreply, state}

      %{input: inp, y: y, vy: vy} = p ->
        # если состояние не меняется — выходим
        if Map.get(inp, input) == value do
          {:noreply, state}
        else
          {p2, inp2} =
            case {input, value} do
              # НАЖАТИЕ прыжка: даём импульс ТОЛЬКО если на земле
              {:jump, true} when y >= @ground_y and vy == 0 ->
                {%{p | vy: -@jump_impulse}, Map.put(inp, :jump, true)}

              # отпускание прыжка — просто запоминаем (на физику сейчас не влияет)
              {:jump, false} ->
                {p, Map.put(inp, :jump, false)}

              # обычные лево/право
              {dir, val} when dir in [:left, :right] ->
                {p, Map.put(inp, dir, val)}

              # любые другие — без изменений
              _ ->
                {p, inp}
            end

          {:noreply, put_in(state.players[player_id], %{p2 | input: inp2})}
        end
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, dead_pid, _reason}, state) do
    id = Enum.find_value(state.players, fn {id, p} -> if p.pid == dead_pid, do: id end)

    state =
      if id do
        PubSub.broadcast(LiveSnake.PubSub, "players", {:despawn, [id]})
        update_in(state.players, &Map.delete(&1, id))
      else
        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, %{players: players, tick_no: t} = state) do
    {players2, changed_xy} =
      :maps.fold(
        fn id, p, {acc, diff} ->
          vx =
            cond do
              p.input.left -> -@move_speed
              p.input.right -> @move_speed
              true -> 0
            end

          vy = p.vy + @gravity

          new_x =
            (p.x + vx)
            |> min(@playground - @player_size)
            |> max(0)

          new_y = p.y + vy

          {final_y, final_vy} =
            if new_y >= @ground_y, do: {@ground_y, 0}, else: {new_y, vy}

          p2 = %{p | x: new_x, y: final_y, vx: vx, vy: final_vy}

          diff2 =
            if p.x != p2.x or p.y != p2.y do
              Map.put(diff, id, {p2.x, p2.y})
            else
              diff
            end

          {Map.put(acc, id, p2), diff2}
        end,
        {%{}, %{}},
        players
      )

    if map_size(changed_xy) > 0 do
      PubSub.broadcast(LiveSnake.PubSub, "players", {:world_update, %{t: t + 1, pts: changed_xy}})
    end

    now = System.monotonic_time(:millisecond)
    have_any = map_size(players2) > 0

    next_gap =
      if have_any do
        next_at = state.next_at + @tick_ms
        max(0, next_at - now)
      else
        @idle_ms
      end

    _ = Process.cancel_timer(state.timer_ref, async: true, info: false)
    ref = Process.send_after(self(), :tick, next_gap)

    next_at =
      if have_any, do: state.next_at + @tick_ms, else: now + @idle_ms

    {:noreply, %{state | players: players2, tick_no: t + 1, timer_ref: ref, next_at: next_at}}
  end

  @impl true
  def handle_continue({:spawn_broadcast, id, x, y}, state) do
    PubSub.broadcast(
      LiveSnake.PubSub,
      "players",
      {:world_update, %{t: state.tick_no, pts: %{id => {x, y}}}}
    )

    {:noreply, state}
  end
end
