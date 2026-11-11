// Wiztchta browser runtime.
//
// LiveView:   new LiveSocket("/live", Socket, {hooks: {...Hooks}})
// Dead views: init()  (scans the page for challenges and solves them)

const BATCH = 256
const running = new WeakMap()
const encoder = new TextEncoder()

function hasLeadingZeroBits(hash, bits) {
  const full = bits >> 3
  const rest = bits & 7
  for (let i = 0; i < full; i++) if (hash[i] !== 0) return false
  return rest === 0 || hash[full] >> (8 - rest) === 0
}

function digest(prefix, nonce) {
  const suffix = encoder.encode(String(nonce))
  const buf = new Uint8Array(prefix.length + suffix.length)
  buf.set(prefix)
  buf.set(suffix, prefix.length)
  return crypto.subtle.digest("SHA-256", buf).then((h) => new Uint8Array(h))
}

// Finds a nonce such that SHA-256(salt + nonce) starts with `difficulty` zero bits.
// Resolves to the nonce as a string, or null if aborted.
export async function solve(salt, difficulty, { signal } = {}) {
  const prefix = encoder.encode(salt)
  for (let start = 0; ; start += BATCH) {
    if (signal && signal.aborted) return null
    const nonces = Array.from({ length: BATCH }, (_, i) => start + i)
    const hashes = await Promise.all(nonces.map((n) => digest(prefix, n)))
    const found = hashes.findIndex((h) => hasLeadingZeroBits(h, difficulty))
    if (found !== -1) return String(nonces[found])
  }
}

function setState(el, state, message) {
  const box = el.querySelector("[data-state]")
  const status = el.querySelector("[data-wiztchta-status]")
  if (box) box.dataset.state = state
  if (status && message) status.textContent = message
}

// Starts solving the proof-of-work challenge rendered in `el` (no-op if the
// same challenge is already being solved).
export function start(el) {
  const salt = el.dataset.salt
  const difficulty = parseInt(el.dataset.difficulty, 10)
  const current = running.get(el)
  if (current && current.salt === salt) return
  if (current) current.controller.abort()

  const controller = new AbortController()
  running.set(el, { salt, controller })

  const input = el.querySelector("input[name$='[response]']")
  input.value = ""

  if (!(window.crypto && crypto.subtle)) {
    setState(el, "error", "Verification requires a secure (HTTPS) connection.")
    return
  }

  setState(el, "solving", "Verifying you are human…")
  solve(salt, difficulty, { signal: controller.signal })
    .then((nonce) => {
      if (nonce === null) return
      input.value = nonce
      setState(el, "solved", "Verified ✓")
    })
    .catch(() => setState(el, "error", "Verification failed. Please reload the page."))
}

export function stop(el) {
  const current = running.get(el)
  if (current) current.controller.abort()
  running.delete(el)
}

// For pages without LiveView. Challenges inside LiveViews are left to the hook.
export function init(root = document) {
  root.querySelectorAll("[data-wiztchta-pow]").forEach((el) => {
    if (!el.closest("[data-phx-session]")) start(el)
  })
}

export const Hooks = {
  WiztchtaProofOfWork: {
    mounted() {
      start(this.el)
    },
    updated() {
      start(this.el)
    },
    destroyed() {
      stop(this.el)
    },
  },
}

export default { Hooks, init, solve, start, stop }
