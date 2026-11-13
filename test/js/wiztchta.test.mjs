// Run with `mix test.js` (or `node --test test/js/`). No npm dependencies:
// a tiny fake DOM covers just what wiztchta.js touches.
import { test } from "node:test"
import assert from "node:assert/strict"
import { createHash } from "node:crypto"

// --- Fake DOM ----------------------------------------------------------------

class FakeElement {
  constructor(tagName, attrs = {}) {
    this.tagName = tagName
    this.attrs = { ...attrs }
    this.dataset = {}
    this.children = []
    this.parent = null
    this.disabled = false
    this.value = ""
    this.textContent = ""
    this.type = attrs.type ?? (tagName === "BUTTON" ? "submit" : "text")
  }
  append(...kids) {
    kids.forEach((kid) => ((kid.parent = this), this.children.push(kid)))
    return this
  }
  remove() {
    this.parent.children = this.parent.children.filter((kid) => kid !== this)
    this.parent = null
  }
  get isConnected() {
    let node = this
    while (node.parent) node = node.parent
    return node === document.body
  }
  closest(tag) {
    for (let node = this; node; node = node.parent) if (node.tagName === tag.toUpperCase()) return node
    return null
  }
  descendants() {
    return this.children.flatMap((kid) => [kid, ...kid.descendants()])
  }
  querySelector(selector) {
    const match = {
      "[data-state]": (el) => "state" in el.dataset,
      "[data-wiztchta-status]": (el) => el.attrs["data-wiztchta-status"] !== undefined,
      "input[name$='[response]']": (el) => el.tagName === "INPUT" && el.attrs.name?.endsWith("[response]"),
    }[selector]
    return this.descendants().find(match) ?? null
  }
  setAttribute(name, value) {
    this.attrs[name] = value
  }
  hasAttribute(name) {
    return name in this.attrs
  }
  removeAttribute(name) {
    delete this.attrs[name]
  }
}

class FakeForm extends FakeElement {
  constructor() {
    super("FORM")
  }
  get elements() {
    return this.descendants().filter((el) => ["BUTTON", "INPUT"].includes(el.tagName))
  }
}

const listeners = []
globalThis.HTMLFormElement = FakeForm
globalThis.window = globalThis
globalThis.document = {
  body: new FakeElement("BODY"),
  addEventListener: (type, fn, capture) => listeners.push({ type, fn, capture }),
}

// Dispatches a submit through the capture listeners; returns whether it got through.
function submit(form) {
  let blocked = false
  const event = {
    target: form,
    preventDefault: () => (blocked = true),
    stopImmediatePropagation: () => {},
  }
  listeners.filter((l) => l.type === "submit" && l.capture).forEach((l) => l.fn(event))
  return !blocked
}

// Builds <form><div data-wiztchta-pow>...</div><button/></form>, like the component renders.
function renderForm({ difficulty = 8, salt = "a".repeat(32), extraButton } = {}) {
  const form = new FakeForm()
  const pow = new FakeElement("DIV")
  pow.dataset.salt = salt
  pow.dataset.difficulty = String(difficulty)
  const box = new FakeElement("DIV")
  box.dataset.state = "pending"
  const input = new FakeElement("INPUT", { type: "hidden", name: "wiztchta[response]" })
  const status = new FakeElement("SPAN", { "data-wiztchta-status": "" })
  pow.append(box.append(input, status))
  const button = new FakeElement("BUTTON")
  form.append(pow, button)
  if (extraButton) form.append(extraButton)
  document.body.append(form)
  return { form, pow, box, input, button }
}

const waitFor = async (check, ms = 5000) => {
  const until = Date.now() + ms
  while (!check()) {
    if (Date.now() > until) throw new Error("timed out")
    await new Promise((r) => setTimeout(r, 5))
  }
}

const { solve, start, stop } = await import("../../priv/static/wiztchta.js")

// --- solve() -----------------------------------------------------------------

test("solve() finds a nonce the server-side rule accepts", async () => {
  const salt = "0123456789abcdef0123456789abcdef"
  const nonce = await solve(salt, 12)
  const hash = createHash("sha256").update(salt + nonce).digest()
  assert.equal(hash[0], 0)
  assert.equal(hash[1] >> 4, 0)
})

test("solve() returns null when aborted", async () => {
  const controller = new AbortController()
  controller.abort()
  assert.equal(await solve("salt", 30, { signal: controller.signal }), null)
})

// --- Submit guard ------------------------------------------------------------

test("blocks submit and disables buttons until solved, then releases", async () => {
  const { form, box, input, button } = renderForm({ difficulty: 10 })
  start(form.children[0])

  assert.equal(box.dataset.state, "solving")
  assert.equal(button.disabled, true)
  assert.equal(submit(form), false)

  await waitFor(() => box.dataset.state === "solved")
  assert.notEqual(input.value, "")
  assert.equal(button.disabled, false)
  assert.equal(submit(form), true)
})

test("leaves buttons the app disabled itself alone", async () => {
  const appDisabled = new FakeElement("BUTTON")
  appDisabled.disabled = true
  const { form, box } = renderForm({ extraButton: appDisabled })
  start(form.children[0])
  await waitFor(() => box.dataset.state === "solved")
  assert.equal(appDisabled.disabled, true)
})

test("ignores non-submit buttons", () => {
  const plain = new FakeElement("BUTTON", { type: "button" })
  const { form } = renderForm({ difficulty: 30, extraButton: plain })
  start(form.children[0])
  assert.equal(plain.disabled, false)
  stop(form.children[0])
})

test("does not block other forms", () => {
  const solving = renderForm({ difficulty: 30 })
  const other = renderForm({ difficulty: 1 })
  start(solving.pow)
  assert.equal(submit(other.form), true)
  stop(solving.pow)
})

test("stop() releases the form even after the element was removed", () => {
  const { form, pow, button } = renderForm({ difficulty: 30 })
  start(pow)
  assert.equal(button.disabled, true)
  pow.remove() // LiveView calls destroyed() after detaching the element
  stop(pow)
  assert.equal(button.disabled, false)
  assert.equal(submit(form), true)
})

test("a new challenge keeps the form locked until it is solved", async () => {
  const { form, pow, box, button } = renderForm({ difficulty: 30 })
  start(pow)
  pow.dataset.salt = "b".repeat(32) // LiveView patched in a new challenge
  pow.dataset.difficulty = "8"
  start(pow)
  assert.equal(button.disabled, true)
  await waitFor(() => box.dataset.state === "solved")
  assert.equal(button.disabled, false)
})

test("without crypto.subtle the form is not trapped", () => {
  const subtle = Object.getOwnPropertyDescriptor(globalThis.crypto, "subtle")
  Object.defineProperty(globalThis.crypto, "subtle", { value: undefined, configurable: true })
  try {
    const { form, pow, box, button } = renderForm()
    start(pow)
    assert.equal(box.dataset.state, "error")
    assert.equal(button.disabled, false)
    assert.equal(submit(form), true)
  } finally {
    Object.defineProperty(globalThis.crypto, "subtle", subtle ?? { value: undefined })
  }
})
