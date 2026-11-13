# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Honeypot trap field, rendered by `<.wiztchta>` and checked first by `Wiztchta.verify/2`,
  which returns the new `{:error, :honeypot}`. Enabled by default; configure with
  `:honeypot` and `:honeypot_field`. Forms rendered without the field still verify.
- Minimum fill time: `Wiztchta.verify/2` returns `{:error, :too_fast}` for submissions
  made less than `:min_time` seconds (default `2`) after the challenge was created. The
  issue time is stored in the encrypted token; too-fast attempts don't consume it.
- Submit guard: forms can't be submitted while their proof-of-work is still solving.
  Submit buttons are disabled (`data-wiztchta-disabled`) and submit events are blocked
  before LiveView or the browser handle them; Enter in a text field is covered too.
- The proof-of-work `:difficulty` is validated (integer 1–32); README documents
  measured solving times to help choose it per form.

### Fixed

- The proof-of-work `data-state` no longer resets to `pending` when LiveView
  re-renders the component; it now lives on `.wiztchta-pow-box`.

### Upgrade notes

- Set `config :wiztchta, min_time: 0` in `config/test.exs`; tests submit forms
  instantly and would otherwise get `{:error, :too_fast}`.
- Consider `min_time: 0` for login forms, which password managers fill instantly.
- Tokens issued by 0.1.x have no issue time and skip the minimum fill time check.
- CSS targeting `data-state` should use `.wiztchta-pow-box[data-state=...]`
  (descendant selectors such as `.wiztchta [data-state=solved]` keep working).

### Changed

- Repository moved to https://github.com/darth-jorge/wiztchta (package links and docs source links updated).

## [0.1.0] - 2026-11-12

### Added

- `<.wiztchta>` form component for controllers and LiveViews.
- `Wiztchta.new/1` and `Wiztchta.verify/2` with encrypted, expiring, single-use tokens.
- `Wiztchta.Challenge` behaviour with built-in proof-of-work (default) and math challenges.
- `Wiztchta.Store` behaviour for replay protection, with an in-memory ETS default.
- `Wiztchta.Plug` for verifying submissions in controller actions.
- Browser runtime (`import { Hooks, init } from "wiztchta"`) with a LiveView hook.

[Unreleased]: https://github.com/darth-jorge/wiztchta/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/darth-jorge/wiztchta/releases/tag/v0.1.0
