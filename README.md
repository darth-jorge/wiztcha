# Wiztchta

[![Hex.pm](https://img.shields.io/hexpm/v/wiztchta.svg)](https://hex.pm/packages/wiztchta)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/wiztchta)
[![License](https://img.shields.io/hexpm/l/wiztchta.svg)](LICENSE)

Drop-in, pluggable CAPTCHA for Phoenix forms and LiveViews. No database, no
third-party service.

```heex
<.form for={@form} phx-submit="save">
  <.input field={@form[:email]} />
  <.wiztchta challenge={@challenge} />
  <.button>Sign up</.button>
</.form>
```

- **Proof-of-work** (default): the browser solves a small SHA-256 puzzle
  invisibly while the person fills in the form. The form can't be submitted
  until it's solved. **Math**: "What is 3 + 4?", which works without JS.
  You can also add your own type with the `Wiztchta.Challenge` behaviour.
- **Honeypot**: a hidden trap field that people never see but naive bots
  fill in. It's added automatically, with no friction for real users.
- **Minimum fill time**: forms submitted faster than a person could fill
  them in (2 seconds by default) are rejected.
- **Stateless**: each challenge travels as an encrypted, expiring token.
- **Replay protection**: each token can only be used once. Used tokens are
  remembered in ETS by default, or in your own `Wiztchta.Store`.

## Installation

```elixir
# mix.exs
{:wiztchta, "~> 0.2"}
```

```elixir
# config/config.exs
config :wiztchta, endpoint: MyAppWeb.Endpoint

# config/test.exs (tests submit instantly; see "Minimum fill time")
config :wiztchta, min_time: 0
```

```elixir
# lib/my_app_web.ex, inside html_helpers
import Wiztchta.Components
```

```js
// assets/js/app.js (Phoenix's esbuild config already resolves packages in deps/)
import { Hooks as WiztchtaHooks, init as initWiztchta } from "wiztchta";

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ...colocatedHooks, ...WiztchtaHooks },
  // ...
});
initWiztchta(); // only needed for forms rendered by controllers
```

Proof-of-work uses `crypto.subtle`, so it needs HTTPS (or localhost).

## LiveView

```elixir
def mount(_params, _session, socket) do
  {:ok, assign(socket, form: to_form(%{}), challenge: Wiztchta.new())}
end

def handle_event("save", params, socket) do
  socket = assign(socket, :challenge, Wiztchta.new()) # tokens are single-use

  case Wiztchta.verify(params) do
    :ok -> {:noreply, ...}
    {:error, reason} -> {:noreply, put_flash(socket, :error, Wiztchta.error_message(reason))}
  end
end
```

Keep the challenge in an assign. Without `challenge={...}`, the component makes
a new challenge each time it renders.

## Controllers

```heex
<.form for={@form} action={~p"/contact"}>
  ...
  <.wiztchta type={Wiztchta.Challenges.Math} />
</.form>
```

```elixir
plug Wiztchta.Plug when action in [:create]

def create(conn, params) do
  case conn.assigns.wiztchta do
    :ok -> ...
    {:error, reason} -> ...
  end
end
```

## Honeypot

Every `<.wiztchta>` also renders a trap field, `wiztchta[website]`. It's a
normal text input moved off-screen, so people never see it and bots that fill
in every input do. `verify/2` checks it first and returns `{:error, :honeypot}`
if it was filled, without touching the token.

Consider pretending a caught bot succeeded instead of showing an error, so it
doesn't learn what gave it away:

```elixir
case Wiztchta.verify(params) do
  :ok -> save(params)
  {:error, :honeypot} -> :discard   # respond as if it worked
  {:error, reason} -> show_error(Wiztchta.error_message(reason))
end
```

The field is hidden with an inline style. If your Content Security Policy
blocks inline styles, hide it in your CSS instead:
`.wiztchta-hp { position: absolute; left: -10000px; }`.

## Proof-of-work difficulty

The puzzle starts solving as soon as the form renders, and the form's submit
buttons stay disabled (and submits blocked) until it's done. Any solving time
shorter than the time a person spends filling in the form is invisible to them.

Solving times measured with the bundled solver (in Node, on a desktop machine).
Phones are typically several times slower, and individual solves vary a lot
around the average:

| `difficulty` | average | slowest of 15 runs |
|---|---|---|
| 14 | 0.07 s | 0.3 s |
| 16 (default) | 0.2 s | 0.7 s |
| 17 | 0.5 s | 1.3 s |
| 18 | 1.3 s | 3.6 s |

Keep the default on quick forms (login, newsletter). Raise it on long forms,
where solving finishes before the person does anyway:

```heex
<.wiztchta challenge={@challenge} />  <%!-- with Wiztchta.new(difficulty: 18) --%>
<.wiztchta opts={[difficulty: 18]} />  <%!-- when generated on render --%>
```

Difficulty can't close the gap with bots that hash natively (several times
faster than a browser), so it works best alongside the honeypot and minimum
fill time.

## Minimum fill time

When a challenge is created, its issue time goes inside the encrypted token,
so it can't be forged. Submissions that arrive less than `min_time` seconds
later return `{:error, :too_fast}`, and the token is not used up, so the
person can simply submit again.

- In LiveViews the clock starts when the challenge is assigned (at mount and
  after each submit).
- For login forms, where password managers fill everything in at once,
  disable it: `<.wiztchta opts={[min_time: 0]} />` and
  `Wiztchta.verify(params, min_time: 0)`.
- Set `config :wiztchta, min_time: 0` in `config/test.exs`, or your tests'
  form submissions will fail with `:too_fast`.
- With several servers, their clocks should be in sync (NTP), since the token
  may be issued on one node and verified on another.

## Configuration

```elixir
config :wiztchta,
  endpoint: MyAppWeb.Endpoint,      # or secret_key_base: "..."
  default_challenge: Wiztchta.Challenges.ProofOfWork,
  pow_difficulty: 16,               # 1..32, each +1 doubles the work
  max_age: 300,                     # seconds a challenge stays valid
  store: Wiztchta.Store.ETS,        # nil disables replay protection
  param: "wiztchta",                # form param name
  honeypot: true,                   # false disables the trap field
  honeypot_field: "website",        # trap field name
  min_time: 2                       # seconds; 0 disables the minimum fill time
```

You can pass any of these per call too, for example
`Wiztchta.new(type: Wiztchta.Challenges.Math, max_age: 60)` or
`<.wiztchta opts={[difficulty: 18]} />`.

The default ETS store only knows about tokens used on its own node. In a cluster, a token could be
used once on each node. Implement `Wiztchta.Store` on top of shared storage to
prevent that.

## Styling

The markup uses plain classes (`wiztchta`, `wiztchta-hp`, `wiztchta-pow`, `wiztchta-status`,
`wiztchta-math`, `wiztchta-label`, `wiztchta-input`), and proof-of-work exposes
`data-state="pending|solving|solved|error"` on `.wiztchta-pow-box`. While a
challenge is solving, the form's submit buttons are disabled and marked with
`data-wiztchta-disabled`. Pass `class` to the component to add your own.

## Development

```sh
mix deps.get
mix test       # Elixir tests
mix test.js    # JS tests (Node 18+, no npm install needed)
mix dev        # demo app at http://localhost:4000 (LiveView + controller forms)
mix precommit
```

## License

MIT. See [LICENSE](LICENSE).
