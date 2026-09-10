# Port Menu workflow

- Native macOS SwiftUI menu bar app. Source lives in `Porter/`; unit tests in `PorterTests/`.
- Read `PRODUCT.md` for fork scope and `README.md` for build commands.
- Preserve the existing English UI and compact menu styling.
- Use Bitrig's build tool for app builds. Unit verification: `xcodebuild test -project Porter.xcodeproj -scheme Porter -destination 'platform=macOS,arch=arm64' -only-testing:PorterTests`.
- LocalCan integration is read-only. Never create, rewrite, or remove saved routes.
- Simulator discovery is read-only; shut down only the specific device selected by the user.
- Bitrig manages publishing. Work on a feature branch, commit changes, and do not push manually.
