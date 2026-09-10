# Port Menu 0.18.19 release review

11 September 2026. This supersedes the remaining activation items in the [earlier review](release-review-0.8.15.md).

## Changes

- Align the grouped PostgreSQL icon and title with the main row, retaining its address, uptime, protected actions, and the original hover controls.
- Use the requested power-plug menu icon, network marker before the branch, and device-specific simulator metadata icons.
- Display only **0.18.19** in Settings and release titles. Keep the internal build counter for Sparkle and macOS.
- Reject an ordinary duplicate launch before SwiftUI creates a menu scene. The previous asynchronous rejection could save the running menu's visibility as false. Installation handoff still waits asynchronously for the source copy to exit.
- Correct the release workflow's temporary-path context and the release script's universal-architecture verification.

## Build and behavior checks

- **105 app tests in 23 suites passed**, including renamed-device icon selection, project grouping, layout, process protection, installer recovery, and update configuration.
- **7 release automation tests** and official Actionlint workflow validation passed. Version progression selects exactly 0.18.19 from the current public feed.
- Bitrig’s underlying build log reports **BUILD SUCCEEDED**. Its wrapper still flags the known AppIntents metadata and ambiguous-destination warnings as failure.
- The rendered 340-point Stock/PostgreSQL/Piqly fixture confirms matching title alignment/typography, the database marker column, the network branch marker, and phone metadata icon.
- All selected SF Symbols load through AppKit on this Mac. The vertical menu plug uses a macOS 15 availability guard and a compatible plug fallback on macOS 14.

## Verified distribution

The fork's encrypted GitHub Actions secrets and public signing variables are configured. The existing Developer ID identity and Apple credential have produced accepted app and DMG notarizations. The first public **0.8.17** release established the signed fork feed; **0.18.19**, internal build 29, is now its latest public release.

The official Sparkle CLI completed a real public-feed update from internal build 25 to 26: download, signature verification, installation, and relaunch. A second probe returned “No new update available!” rather than a retrieval error. The app's visible manual button and hourly scheduler were not used for that test.

A live duplicate-launch test of the synchronous fix exited successfully while the installed **0.8.18** copy stayed running alone. Menu visibility stayed true, no preference names changed, and the installed app's metadata was untouched. No monitored server, database, or simulator was stopped.

The complete release script also passed locally for **0.18.19**, built from `cbe93f341d7ad58f04711fee3780b8854e5804e7`. Both universal slices, Developer ID signatures, app/DMG notarization, stapled tickets, Gatekeeper assessment, and the signed feed’s version/download ownership checks passed. Apple accepted local app submission `61a3d0b3-27de-4451-8cef-828ff093ba45` and local DMG submission `13c7f824-762c-4d66-9e12-b4d72fd85fc3`. These local artifacts were not published.

After Bitrig published the feature branch, [pull request #2](https://github.com/kuricialm/port-menu/pull/2) merged the verified app/build trees into remote main at `eb04433c0e87777ee8b23e6c5eff656ad28e3371`. [GitHub Actions run 34536377365](https://github.com/kuricialm/port-menu/actions/runs/34536377365) passed tests, signing, app/DMG notarization, signed-feed validation, and publication. It independently built and published [Port Menu 0.18.19](https://github.com/kuricialm/port-menu/releases/tag/v0.18.19) with internal build 29. This completes the first hosted release verification.

The public DMG, appcast, and checksum file were downloaded and their SHA-256 hashes matched GitHub's asset digests. The hosted DMG hash is `7bd68914388eb578d27853c184dab87849f799fbd1268355f82bbdfccee37d74`; the hosted appcast hash is `48d96bf3d17ad70d951f1ff715147658088bfeb84442abb64eb997aa91a3da18`. The official Sparkle CLI's read-only probe confirmed the available update through the installed app's feed. No installation was attempted by that probe.

The final **0.18.19** build is intentionally not installed by the agent: the user requested to test it through **Check for Updates**. That visible manual-button test and its resulting installation remain user acceptance steps; the hosted publication and read-only update probe are complete.

## Remaining findings and acceptance

| Priority | Status |
| --- | --- |
| Critical | No confirmed unresolved Critical defect in the reviewed scope. |
| High | No confirmed unresolved High defect in the reviewed scope. The hosted activation finding is closed by successful run 34536377365, exact-source publication, downloaded asset verification, and the Sparkle update probe. |
| Medium | Opening a Bitrig simulator brings Bitrig forward; exact project selection still needs a documented host API. Bitrig also misclassifies the known Xcode metadata/destination warnings despite the underlying successful build. |
| Low | Live keyboard/VoiceOver and hover acceptance, macOS 14/Intel execution, launch-at-login, and watchOS/tvOS/visionOS runtime acceptance remain unverified on this Mac. Device-icon mapping is covered separately from launching those runtimes. |

The earlier process-termination, database protection, stale-data, LocalCan parsing, subprocess, and installer rollback fixes remain in place. This pass preserves the 340-point menu and does not add resource monitoring or change LocalCan routes.
