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

// --- Submit guard ------------------------------------------------------------
//
// While a challenge is being solved its form must not be submitted. Two layers:
//
// 1. A capture-phase "submit" listener on document blocks the submission. It
//    runs before LiveView's (bubbling, on window) and before native
//    submission, and also catches Enter in a text field.
// 2. The form's submit buttons are disabled as a visual cue. LiveView may
//    re-render a button and drop `disabled`; layer 1 still holds.
//
// Pending challenges are tracked in memory (element -> its form), not in DOM
// attributes that LiveView patches could overwrite. The form is remembered
// because a destroyed hook's element is already detached from it.

const pending = new Map()
const LOCK_ATTR = "data-wiztchta-disabled"
let guardInstalled = false

function submitButtons(form) {
  return Array.from(form.elements).filter(
    (el) =>
      (el.tagName === "BUTTON" && el.type === "submit") ||
      (el.tagName === "INPUT" && (el.type === "submit" || el.type === "image")),
  )
}

function pendingIn(form) {
  return Array.from(pending)
    .filter(([el, elForm]) => elForm === form && el.isConnected)
    .map(([el]) => el)
}

function installGuard() {
  if (guardInstalled) return
  guardInstalled = true
  document.addEventListener(
    "submit",
    (e) => {
      const blocking = e.target instanceof HTMLFormElement ? pendingIn(e.target) : []
      if (blocking.length === 0) return
      e.preventDefault()
      e.stopImmediatePropagation()
      blocking.forEach((el) => setState(el, "solving", "Almost done, still verifying…"))
    },
    true,
  )
}

function lock(el) {
  const form = el.closest("form")
  pending.set(el, form)
  installGuard()
  if (!form) return
  submitButtons(form)
    .filter((button) => !button.disabled)
    .forEach((button) => {
      button.disabled = true
      button.setAttribute(LOCK_ATTR, "")
    })
}

function unlock(el) {
  const form = pending.has(el) ? pending.get(el) : el.closest("form")
  pending.delete(el)
  if (!form || pendingIn(form).length > 0) return
  submitButtons(form)
    .filter((button) => button.hasAttribute(LOCK_ATTR))
    .forEach((button) => {
      button.disabled = false
      button.removeAttribute(LOCK_ATTR)
    })
}

// --- Lifecycle ---------------------------------------------------------------

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
    // Don't trap the user behind a disabled form; the server rejects the submit.
    unlock(el)
    setState(el, "error", "Verification requires a secure (HTTPS) connection.")
    return
  }

  lock(el)
  setState(el, "solving", "Verifying you are human…")
  solve(salt, difficulty, { signal: controller.signal })
    .then((nonce) => {
      if (nonce === null) return // superseded by a newer challenge, which owns the lock
      input.value = nonce
      unlock(el)
      setState(el, "solved", "Verified ✓")
    })
    .catch(() => {
      unlock(el)
      setState(el, "error", "Verification failed. Please reload the page.")
    })
}

export function stop(el) {
  const current = running.get(el)
  if (current) current.controller.abort()
  running.delete(el)
  unlock(el)
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
