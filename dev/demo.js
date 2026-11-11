import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { Hooks, init } from "wiztchta"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, params: { _csrf_token: csrfToken } })
liveSocket.connect()

// Solve challenges on pages that aren't LiveViews.
init()
