// assets/js/app.js
import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

// Если есть хуки — объяви их
let Hooks = window.Hooks || {}
// (если хуков нет — оставь пустой объект)

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content")

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks
})

// Подключаем LiveView WebSocket
liveSocket.connect()
