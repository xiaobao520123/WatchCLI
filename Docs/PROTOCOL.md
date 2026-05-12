# WatchCLI Wire Protocol — v1

JSON-over-WebSocket between the watchOS / iOS clients and `watchcli-daemon`.

- **Endpoint**: `GET /v1/session` (WebSocket upgrade).
- **Auth**: `Authorization: Bearer <token>` header, **or** `?token=<token>`
  query string. Compared in constant time on the server.
- **Health** (no auth): `GET /health` → `{"ok":true,"version":"…","protocol":"1"}`.
- **Encoding**: every WebSocket text frame is one JSON object with a `type`
  discriminator and (usually) a `payload`.

## Server → Client

| `type`   | Payload                                                    | Notes                                |
|----------|-------------------------------------------------------------|--------------------------------------|
| `banner` | `{ protocolVersion, daemonVersion, agent, hostname }`       | Sent once after upgrade.             |
| `output` | `{ stream: "stdout"\|"stderr", data: String }`             | May contain ANSI escapes.            |
| `exit`   | `{ code: Int32 }`                                           | Sent when a command finishes.        |
| `error`  | `{ code: String, message: String }`                         | Machine-readable + human message.    |
| `pong`   | `{ id: UInt64 }`                                            | Reply to `ping`.                     |

## Client → Server

| `type`   | Payload                                                  | Notes                                          |
|----------|-----------------------------------------------------------|------------------------------------------------|
| `start`  | `{ agent: String, cols, rows, env? }`                     | Pick agent: `shell`, `claude`, `copilot`.      |
| `input`  | `{ data: String }`                                        | One command line per message in P2 (P6 → PTY). |
| `resize` | `{ cols: UInt16, rows: UInt16 }`                          | No-op until P6.                                |
| `signal` | `{ signal: Int32 }`                                       | POSIX signal number.                           |
| `ping`   | `{ id: UInt64 }` (top-level, not under `payload`)         | Liveness.                                      |
| `stop`   | —                                                         | Cleanly stop the running command.              |

## Built-in agents (P2 scope)

- `shell`   → `$SHELL -l -c <data>`
- `claude`  → `$SHELL -l -c "claude '<data>'"`     *(P6 will swap in a PTY)*
- `copilot` → `$SHELL -l -c "copilot '<data>'"`    *(P6 will swap in a PTY)*

Each `input` is currently treated as a single one-shot command, with
stdout / stderr streamed back as `output` frames and a final `exit`. Sending
a new `input` while one is running cancels the previous child.

## Versioning

The protocol carries `protocolVersion` in the banner. The constant
`ProtocolVersion.current` in `WatchCLIProtocol` is the only place to bump.
Backwards-compatible additions can be made without bumping; semantic changes
require a new path (e.g. `/v2/session`) and a coexisting handler.

## Wire example

```
C → S  {"type":"start","payload":{"agent":"shell","cols":80,"rows":24}}
S → C  {"type":"banner","payload":{"protocolVersion":"1","daemonVersion":"0.1.0","agent":"","hostname":"mbp.local"}}
S → C  {"type":"output","payload":{"stream":"stdout","data":"[watchcli] agent=shell ready\n"}}
C → S  {"type":"input","payload":{"data":"echo hi"}}
S → C  {"type":"output","payload":{"stream":"stdout","data":"hi\n"}}
S → C  {"type":"output","payload":{"stream":"stdout","data":"\n[exit 0]\n"}}
```
