# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Honeypot trap field, rendered by `<.wiztchta>` and checked first by `Wiztchta.verify/2`,
  which returns the new `{:error, :honeypot}`. Enabled by default; configure with
  `:honeypot` and `:honeypot_field`. Forms rendered without the field still verify.

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
