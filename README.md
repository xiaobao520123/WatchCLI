# WatchCLI

> AI Agent CLI on your Apple Watch. Code at anytime!

A SwiftUI watchOS terminal client + companion iOS app + small Swift daemon
that lets you drive a real shell or AI CLI (Claude Code, Copilot CLI, …)
running on your Mac, workstation or server — straight from your wrist, by
**voice or touch**.

Inspired by the Claude Code CLI; designed for the watch, not ported to it.

## Architecture

```
 ┌──────────────┐  WebSocket / TLS + bearer token  ┌──────────────────────┐
 │ watchOS app  │ ◄──────────────────────────────► │ watchcli-daemon      │
 │ (SwiftUI)    │                                  │ (Swift, Hummingbird) │
 └──────┬───────┘                                  │  ├─ PTY shell        │
        │ WatchConnectivity (P5)                   │  ├─ AI CLI runners   │
 ┌──────▼───────┐                                  │  └─ Token auth       │
 │ iOS app      │                                  └──────────────────────┘
 │ (SwiftUI)    │
 └──────────────┘
```

Three Swift modules in this repo, all in one SwiftPM package:

| Module               | Kind        | Purpose                                   |
| -------------------- | ----------- | ----------------------------------------- |
| `WatchCLIProtocol`   | library     | Codable wire types shared by all targets  |
| `WatchCLIDaemon`     | executable  | The server you run on your Mac/box        |
| watchOS / iOS apps   | xcodegen    | Clients (under `Apps/`)                   |

## Requirements

- macOS 14+, Xcode 16+ (this repo is developed against Xcode 26.5)
- [`xcodegen`](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Quick start

```bash
# 1. Build everything (regenerates the Xcode project)
./scripts/build.sh

# 2. Run all tests
./scripts/test.sh

# 3. Start the daemon on your Mac (P2+)
./scripts/run-daemon.sh

# 4. Open the apps in Xcode
open WatchCLI.xcodeproj
```

## Status — phased delivery

- ✅ **P1 — Scaffolding** (this commit): SwiftPM package, `WatchCLIProtocol`
  with full v1 wire types and round-trip tests, daemon stub, watchOS + iOS
  app skeletons that build for their respective simulators.
- ⏳ **P2 — Daemon MVP**: Hummingbird WebSocket server, token auth,
  PTY-backed `/bin/zsh` session, stream stdout/stdin.
- ⏳ **P3 — Watch terminal MVP**: live connection from the watch, render
  streamed output in the terminal pane.
- ⏳ **P4 — Compose & dictation**: Speech-framework dictation, slash-command
  palette, persisted history.
- ⏳ **P5 — iOS sync**: WatchConnectivity-based endpoint sync.
- ⏳ **P6 — Agents & polish**: presets for `shell` / `claude` / `copilot`,
  ANSI handling, reconnect, haptics.

See `Docs/` (added per-phase) for protocol docs and ops notes.

## License

MIT. See [`LICENSE`](LICENSE).
