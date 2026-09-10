# Port Menu workflow

- Native macOS SwiftUI menu bar app. Source lives in `Porter/`; unit tests in `PorterTests/`.
- Read `PRODUCT.md` for fork scope and `README.md` for build commands.
- Preserve the author’s original English UI, two-line rows, compact spacing, animated action reveal, capsule button styling, and hover/press springs. Use labeled SF Symbol actions when added controls would crowd a row; do not introduce extra action lines or permanently visible controls.
- Use Bitrig's build tool for app builds. Unit verification: `xcodebuild test -project Porter.xcodeproj -scheme Porter -destination 'platform=macOS,arch=arm64' -only-testing:PorterTests`.
- LocalCan integration is read-only. Never create, rewrite, or remove saved routes.
- Simulator discovery is read-only; shut down only the specific device selected by the user.
- Bitrig manages publishing. Work on a feature branch, commit changes, and do not push manually. Leave the feature branch selected at the end of the turn: Bitrig does not publish the default branch. Verify the feature commit exists on GitHub before merging its pull request into remote main; a local merge into main does not publish a release.

## Version identification

- For every batch of app changes published by Bitrig, increment the patch component of `MARKETING_VERSION` and increment `CURRENT_PROJECT_VERSION` before the final build and commit. Keep Debug/Release and test targets consistent. Never reuse a version for a changed app build that the user will install. Documentation-only changes do not require an app release.
- Show only the release version in the app's Settings popover and public release title (starting at 0.18.19). Keep incrementing the internal build number for Sparkle and macOS. Report the exact release version in the handoff and distinguish a successful build from a verified installation in `/Applications/Port Menu.app`.

## Distribution

- Follow `docs/releasing.md` for signing, notarization, GitHub Actions, and Sparkle. Do not point this fork at upstream's feed or reuse upstream's update key. Keep private signing material out of Git and logs.
- The release workflow advances version/build in its artifact if source versions were already published; continue bumping the project version for Bitrig app-change batches as above.
- `python3 scripts/test-release-metadata.py` verifies version progression and feed ownership.
