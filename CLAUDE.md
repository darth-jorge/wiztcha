# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Wiztchta is a **Hex/Mix library** (not a Phoenix app) that host Phoenix projects add as a dependency to put a CAPTCHA in any form: `<.wiztchta />` + `Wiztchta.verify/2`. It has no database, Endpoint, Repo or config of its own. Host apps supply the secret (`config :wiztchta, endpoint: MyAppWeb.Endpoint`).

`AGENTS.md` holds the Elixir/HEEx/LiveView coding rules. Follow them, but skip the app-only parts (`Layouts.app`, `current_scope`, router scopes, `core_components` `<.input>`/`<.icon>`), which don't exist in a library:

@AGENTS.md

## Commands

- `mix test` / `mix test test/wiztchta_test.exs:42` / `mix test --failed`
- `mix dev`: runs `dev.exs`, a single-file Phoenix demo app (LiveView form at `/`, controller form at `/classic`) on port 4000 (`PORT` to override). Uses `dev/demo.js` + `dev/demo.css` and a browser import map, with no bundler.
- `mix test.js`: JS tests via `node --test test/js/` with a minimal fake DOM (no npm dependencies).
- `mix precommit`: run when done. It runs `compile --warnings-as-errors`, `deps.unlock --unused`, `format`, `test` and `test.js`.

## Architecture

Request flow: `Wiztchta.new/1` asks a challenge module for `{public, secret}` and then encrypts `%{id, type, secret, expires_at}` into a token (`Wiztchta.Token`, `Plug.Crypto.encrypt`). It encrypts rather than signs so answers like the math result stay hidden. The component renders the hidden `wiztchta[token]` input and delegates the challenge UI to `type.render/1`, which must submit `wiztchta[response]`. `Wiztchta.verify/2` first rejects a filled `Wiztchta.Honeypot` field (rendered by the component, checked before any token work), then decrypts the token, rejects it if younger than `:min_time` (`issued_at` in the payload; tokens without it skip the check), **consumes it in the store before checking the answer** (this stops retrying the same token), then calls `type.valid?/3`.

- `Wiztchta.Config`: every setting is resolved per call opts → app env → defaults. Secret comes from `:secret_key_base` or `:endpoint`.
- `Wiztchta.Challenge`: behaviour (`generate/1`, `valid?/3`, `render/1`) and the `%Challenge{type, token, public}` struct. Built-ins live in `lib/wiztchta/challenges/`: `ProofOfWork` (default) and `Math`.
- `Wiztchta.Store`: replay-protection behaviour. `Store.ETS` is started by `Wiztchta.Application` (the only supervised process) and uses `:ets.insert_new` for atomic consume plus a minute-by-minute sweep.
- `Wiztchta.Plug`: for controllers. It assigns `conn.assigns.wiztchta` and never halts.
- JS runtime: `priv/static/wiztchta.js` is a plain ES module with no build step, exported via root `package.json`. Hosts `import { Hooks, init } from "wiztchta"`, which Phoenix's esbuild resolves through `NODE_PATH=deps`. The proof-of-work algorithm must stay byte-identical between `solve()` in JS and `ProofOfWork.valid?/3`: `SHA-256(salt_hex_string <> decimal_nonce)` with N leading zero bits.
- LiveView: the PoW hook element carries `data-salt`. Its answer input and status sit in a `phx-update="ignore"` child, so patches don't clear the solved nonce, and `updated()` restarts solving when the salt changes. LiveView still syncs the `data-*` attributes *of the ignored container itself* with the server, so JS-owned state (`data-state`) lives on its child `.wiztchta-pow-box`. `init()` skips anything inside `[data-phx-session]`.
- Submit guard (JS): pending challenges are tracked in memory (`Map` element → form), never in DOM attributes. A capture-phase `submit` listener on `document` blocks forms with a pending challenge before LiveView's bubbling `window` listener; disabling submit buttons is only a visual cue, since LiveView restores button state after submits.
- Tests use `Wiztchta.Test.FixedChallenge` (`test/support`, answer `"42"`) for deterministic round-trips. The secret is set in `test/test_helper.exs`, which also sets `min_time: 0`; min-time tests pass explicit opts or build tokens with a past `issued_at`.
