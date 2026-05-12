# Installing WatchCLI on a real iPhone + Apple Watch

Apple requires every app installed on a physical device to be code-signed,
even for personal use. The free **Apple ID personal team** works fine and
takes about 60 seconds to set up.

## One-time setup

### 1. Sign in to Xcode with an Apple ID

1. Open **Xcode**.
2. **Xcode → Settings → Accounts**.
3. Click **+**, choose **Apple ID**, sign in with any Apple ID. The "free"
   personal team is created automatically — no paid Developer Program
   membership needed for personal-device installs.

### 2. Trust the iPhone

1. Plug the iPhone into the Mac with a USB-C cable.
2. On the iPhone, tap **Trust This Computer** when prompted.
3. **Settings → Privacy & Security → Developer Mode → On** (the iPhone
   will reboot once).
4. Plug it in again so Xcode can mount its Developer Disk Image (this
   happens automatically the first time you run *anything* with the device
   selected as a destination — opening `WatchCLI.xcodeproj` once and
   selecting your iPhone in the device picker is enough).

### 3. Pair the Apple Watch

If your Watch is already paired with the iPhone (which it is if you set it
up normally), you don't need to do anything. The companion watchOS app
ships *inside* the iPhone .app bundle and is auto-deployed to the Watch
the first time you install the iOS app.

### 4. Set the team in the project (one line)

Edit `Project.yml` and add your Team ID under `settings.base`:

```yaml
settings:
  base:
    DEVELOPMENT_TEAM: "ABCDE12345"   # ← your 10-char Team ID
```

You can find your Team ID in **Xcode → Settings → Accounts → Manage
Certificates → (your team)**, or by running:

```bash
security find-identity -v -p codesigning
# "Apple Development: you@example.com (ABCDE12345)"
```

Then regenerate:

```bash
xcodegen generate
```

> Skip step 4 if you'd rather just open the project in Xcode and click
> "Automatically manage signing" in the Signing & Capabilities tab once
> per target. The script will pick up the resulting profile.

## Install

```bash
./scripts/install-on-device.sh
```

That's it. The script:

1. Detects your connected iPhone via `xcrun devicectl`.
2. Verifies a signing identity is present.
3. Builds the **Release** configuration for the device.
4. Installs the iPhone app via `devicectl`.
5. Tells the iPhone to mirror the embedded watch app to the Watch.

The Apple Watch install can take **1–2 minutes** the first time. You can
watch progress in the iPhone's Watch app under "Available Apps".

## Troubleshooting

| Symptom | Fix |
|---|---|
| `No code-signing identity found` | Step 1 above — sign in to Xcode. |
| `connected (no DDI)` in `devicectl list` | Open Xcode once with the device selected; it mounts the Developer Disk Image automatically. |
| Install succeeds but iOS shows "Untrusted Developer" on launch | iPhone → Settings → General → VPN & Device Management → tap your developer profile → **Trust**. |
| Watch app doesn't appear | iPhone → Watch app → My Watch → scroll to **Available Apps** → tap **Install** next to WatchCLI. |
| Free personal team apps expire after 7 days | This is an Apple limitation; just re-run `./scripts/install-on-device.sh`. A paid Developer Program membership ($99/yr) extends this to 1 year. |
