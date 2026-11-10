# DockPilot

A tiny macOS menu-bar app that puts the **Dock on the display you're actually using**.

On a multi-monitor Mac the Dock is tied to the *main* display and only moves if
you deliberately shove the cursor to the very bottom edge of another screen.
DockPilot fixes that with two modes:

- **Auto (follow cursor)** — the Dock moves to whichever display your cursor is
  working on, after a short, configurable delay.
- **Manual (pin)** — lock the Dock to one display of your choice; DockPilot keeps
  it there even across sleep / display reconnects.

> **How it works & the one trade-off.** macOS exposes no public API to move *only*
> the Dock. The Dock (and the menu bar) live on the **main display**, so DockPilot
> moves the Dock by making the target display the main one via CoreGraphics
> (`CGConfigureDisplayOrigin`). **This means the menu bar moves together with the
> Dock.** That is by design and is the accepted trade-off for reliable behavior.

No Accessibility or other permissions are required: cursor tracking uses
`NSEvent.mouseLocation` polling, and changing the main display needs no entitlement.

## Requirements

- macOS 14 (Sonoma) or later
- For building: Xcode / Swift toolchain (Swift 6+)

## Build & run

```bash
# Compile and launch (menu-bar only — look for the Dock icon in the status bar)
make run

# Or step by step
make build          # release binary
make app            # assemble build/DockPilot.app (ad-hoc signed)
make install        # copy to /Applications
make dmg            # package a drag-to-install DMG into build/
```

To sign with your own identity (so it launches cleanly on your Mac):

```bash
SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" make dmg
```

Quit from the app's own menu (**退出 DockPilot**).

## Usage

Click the menu-bar icon:

- **模式** — switch between *自动跟随光标* (auto) and *固定到指定屏幕* (manual).
- **屏幕列表** — the current main display is checked; in manual mode, click a
  display to pin the Dock there (`📌`).
- **切换延迟** — in auto mode, how long the cursor must rest on a display before
  the Dock follows (0.2–1.2 s). Raise it if switches feel too eager.
- **开机启动** — register as a login item (requires a signed `.app`).

## Distribution (signing & notarization)

Ad-hoc signing is fine for personal use. To distribute to others, sign with a
**Developer ID Application** certificate and notarize:

```bash
# 1. Build + sign with your Developer ID (timestamp required for notarization)
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" TIMESTAMP=1 ./scripts/build-app.sh

# 2. Store notary credentials once
xcrun notarytool store-credentials "dockpilot-notary" \
    --key /path/to/AuthKey_XXXX.p8 --key-id XXXX --issuer <issuer-uuid>

# 3. Notarize + staple
make notarize
```

## Project layout

```
Sources/DockPilot/
  main.swift            # entry point (accessory app, no Dock icon)
  AppDelegate.swift     # status-item menu, mode logic, login item
  DisplayManager.swift  # CoreGraphics display enumeration + setMainDisplay
  CursorMonitor.swift   # debounced cursor-position polling
  Settings.swift        # UserDefaults-backed preferences
scripts/                # app bundling, signing, notarization
```

## Troubleshooting

**Auto-follow isn't working / "it only works after I switch manually".**
You are probably in **manual** mode. Picking a display once puts the app in
*固定到指定屏幕* (manual), which turns the cursor monitor off. Open the menu and
choose **自动跟随光标** to resume auto-follow. The menu's top line always shows the
current mode. (Mode is remembered across launches.)

**Enable a diagnostic log.** Create the sentinel file, relaunch, reproduce, then
read the log:

```bash
touch /tmp/dockpilot.debug      # turn logging on
open -n /Applications/DockPilot.app
# ... reproduce ...
cat /tmp/dockpilot.log
rm /tmp/dockpilot.debug         # turn logging off
```

## License

[MIT](LICENSE) © 2026 MingHua Li
