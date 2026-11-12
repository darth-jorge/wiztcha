# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-11-12

### Added

- `<.wiztchta>` form component for controllers and LiveViews.
- `Wiztchta.new/1` and `Wiztchta.verify/2` with encrypted, expiring, single-use tokens.
- `Wiztchta.Challenge` behaviour with built-in proof-of-work (default) and math challenges.
- `Wiztchta.Store` behaviour for replay protection, with an in-memory ETS default.
- `Wiztchta.Plug` for verifying submissions in controller actions.
- Browser runtime (`import { Hooks, init } from "wiztchta"`) with a LiveView hook.
