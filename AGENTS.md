# Port Menu workflow

- Native macOS SwiftUI menu bar app. Source lives in `Porter/`; unit tests in `PorterTests/`.
- Read `PRODUCT.md` for fork scope and `README.md` for build commands.
- Preserve the author’s original English UI, two-line rows, compact spacing, animated action reveal, capsule button styling, and hover/press springs. Use labeled SF Symbol actions when added controls would crowd a row; do not introduce extra action lines or permanently visible controls.
- Use Bitrig's build tool for app builds. Unit verification: `xcodebuild test -project Porter.xcodeproj -scheme Porter -destination 'platform=macOS,arch=arm64' -only-testing:PorterTests`.
- LocalCan integration is read-only. Never create, rewrite, or remove saved routes.
- Simulator discovery is read-only; shut down only the specific device selected by the user.
- Bitrig manages publishing. Work on a feature branch, commit changes, and do not push manually.

## Version identification

- For every batch of app changes published by Bitrig, increment the patch component of `MARKETING_VERSION` and increment `CURRENT_PROJECT_VERSION` before the final build and commit. Keep Debug/Release and test targets consistent. Never reuse a version for a changed app build that the user will install. Documentation-only changes do not require an app release.
- Show version and build in the app's Settings popover. Report the exact version in the handoff and distinguish a successful build from a verified installation in `/Applications/Port Menu.app`.
