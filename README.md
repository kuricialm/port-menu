# Port Menu

**localhost, organized.**

A tiny macOS menu bar app that tracks your dev servers across projects.

Based on [Eduard Wieandt’s Port Menu](https://github.com/wieandteduard/port-menu), retaining its compact interface and motion.

---

## What it does

Port Menu sits in your menu bar and automatically detects local development servers running on your machine. One click to see what's running, which project it belongs to, and on which port.

- **Auto-detection** — scans for running dev servers every few seconds
- **Project context** — shows Git repo name, current branch, port, and uptime
- **Kill or open** — stop a server or open it in your browser directly from the menu
- **LocalCan URLs** — reads existing enabled `.local` endpoints from `~/.localcan/projects`, with separate local and localhost open actions
- **Simulators** — lists booted Apple Simulator devices and detected running apps, with Show and Shut Down actions
- **Copy URL** — right-click to copy a saved LocalCan or localhost URL

## Download

**[Fork releases for macOS →](https://github.com/kuricialm/port-menu/releases)**

The first signed fork release is pending the one-time signing setup in [docs/releasing.md](docs/releasing.md).

Requires macOS 14 (Sonoma) or later.

1. Download and open the DMG
2. Drag `Port Menu.app` into `Applications`
3. Open Port Menu from `Applications`
4. Click the icon in your menu bar to get started

## Build from source

```bash
git clone https://github.com/kuricialm/port-menu.git
cd port-menu
open Porter.xcodeproj
```

Requires Xcode 16 or later with Swift 6.

## Release

The automatic release workflow publishes signed, notarized builds on this fork’s [GitHub Releases](https://github.com/kuricialm/port-menu/releases) page after signing credentials are configured. Sparkle checks that channel from the app.

Maintainers can follow the release process in `docs/releasing.md`.

## Testing

```bash
xcodebuild test -project "Porter.xcodeproj" -scheme "Porter" -destination "platform=macOS,arch=arm64" -only-testing:PorterTests
```

## License

MIT
