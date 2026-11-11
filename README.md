# Wiztchta

Drop-in, pluggable CAPTCHA for Phoenix forms and LiveViews. No database, no
third-party service.

```heex
<.form for={@form} phx-submit="save">
  <.input field={@form[:email]} />
  <.wiztchta challenge={@challenge} />
  <.button>Sign up</.button>
</.form>
```

- **Proof-of-work** (default): the browser solves a small SHA-256 puzzle in
  about a second, invisibly. **Math**: "What is 3 + 4?", which works without JS.
  You can also add your own type with the `Wiztchta.Challenge` behaviour.
- **Stateless**: each challenge travels as an encrypted, expiring token.
- **Replay protection**: each token can only be used once. Used tokens are
  remembered in ETS by default, or in your own `Wiztchta.Store`.

## Installation

```elixir
# mix.exs
{:wiztchta, github: "darth-jorge/wiztchta"}
```

```elixir
# config/config.exs
config :wiztchta, endpoint: MyAppWeb.Endpoint
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

## Configuration

```elixir
config :wiztchta,
  endpoint: MyAppWeb.Endpoint,      # or secret_key_base: "..."
  default_challenge: Wiztchta.Challenges.ProofOfWork,
  pow_difficulty: 16,               # each +1 doubles the work
  max_age: 300,                     # seconds a challenge stays valid
  store: Wiztchta.Store.ETS,        # nil disables replay protection
  param: "wiztchta"                 # form param name
```

You can pass any of these per call too, for example
`Wiztchta.new(type: Wiztchta.Challenges.Math, max_age: 60)` or
`<.wiztchta opts={[difficulty: 18]} />`.

The default ETS store only knows about tokens used on its own node. In a cluster, a token could be
used once on each node. Implement `Wiztchta.Store` on top of shared storage to
prevent that.

## Styling

The markup uses plain classes (`wiztchta`, `wiztchta-pow`, `wiztchta-status`,
`wiztchta-math`, `wiztchta-label`, `wiztchta-input`), and proof-of-work exposes
`data-state="pending|solving|solved|error"`. Pass `class` to the component to
add your own.

## Development

```sh
mix deps.get
mix test
mix dev        # demo app at http://localhost:4000 (LiveView + controller forms)
mix precommit
```

## License

MIT. See [LICENSE](LICENSE).
