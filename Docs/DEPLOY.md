# Deploying `watchcli-daemon`

The daemon is a single self-contained Swift binary. There's no GUI; you run
it once and forget about it.

## 1. Build a release binary

```bash
./scripts/build.sh                         # debug build, used by tests
swift build -c release                     # ~5 MB statically-linked binary
cp .build/release/watchcli-daemon /usr/local/bin/
```

## 2. Pick how to run it

### Option A — Foreground (development)

```bash
./scripts/run-daemon.sh
# or:
watchcli-daemon --host 127.0.0.1 --port 8765
```

The first launch generates a random bearer token at
`~/.config/watchcli/token`; copy it into the iPhone companion app.

### Option B — launchd (always-on, restart on crash)

A ready-to-use plist lives at `Docs/dev.watchcli.daemon.plist`. Edit the
`ProgramArguments` to point at your installed binary, then:

```bash
cp Docs/dev.watchcli.daemon.plist ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/dev.watchcli.daemon.plist
launchctl start dev.watchcli.daemon
tail -f /tmp/watchcli-daemon.log
```

To stop / unload:

```bash
launchctl unload -w ~/Library/LaunchAgents/dev.watchcli.daemon.plist
```

## 3. Network exposure

The daemon binds **127.0.0.1** by default. To reach it from a watch on the
same Wi-Fi, switch to `--host 0.0.0.0` and open the firewall on port 8765:

```bash
watchcli-daemon --host 0.0.0.0 --port 8765
# macOS firewall (System Settings → Network → Firewall) usually prompts the
# first time the binary tries to listen on a non-loopback address.
```

For LTE / over-the-internet use, **don't** expose `ws://` directly. Put the
daemon behind something that does TLS termination + auth proxying:

### Caddy (one-line TLS proxy)

```
/etc/caddy/Caddyfile
————————————————————
watchcli.example.com {
    reverse_proxy 127.0.0.1:8765
}
```

Caddy obtains a Let's Encrypt cert automatically. Then point the iPhone
endpoint at `wss://watchcli.example.com/v1/session` (note **wss**), keep
the same bearer token, and you're done.

### nginx (manual TLS)

```nginx
server {
    listen 443 ssl http2;
    server_name watchcli.example.com;
    ssl_certificate     /etc/ssl/certs/fullchain.pem;
    ssl_certificate_key /etc/ssl/private/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8765;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 24h;     # WebSocket can idle a long time
    }
}
```

## 4. Token rotation

To rotate the token, just delete the file and restart:

```bash
rm ~/.config/watchcli/token
launchctl kickstart -k gui/$UID/dev.watchcli.daemon
cat ~/.config/watchcli/token       # the new token
```

Then update the endpoint's token in the iPhone app.

## 5. Health check

```
GET http://<host>:8765/health  →  {"ok":true,"version":"…","protocol":"1"}
```

No auth required; safe for monitoring scripts.
