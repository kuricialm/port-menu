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

The fork's encrypted GitHub Actions secrets and public signing variables are configured. The existing Developer ID identity and Apple credential have produced accepted app and DMG notarizations. The public **0.8.17** release and signed fork feed are live.

The official Sparkle CLI completed a real public-feed update from internal build 25 to 26: download, signature verification, installation, and relaunch. A second probe returned “No new update available!” rather than a retrieval error. The app's visible manual button and hourly scheduler were not used for that test.

A live duplicate-launch test of the synchronous fix exited successfully while the installed **0.8.18** copy stayed running alone. Menu visibility stayed true, no preference names changed, and the installed app's metadata was untouched. No monitored server, database, or simulator was stopped.

The complete release script also passed for **0.18.19**, built from `cbe93f341d7ad58f04711fee3780b8854e5804e7`. Both universal slices, Developer ID signatures, app/DMG notarization, stapled tickets, Gatekeeper assessment, and the signed feed’s version/download ownership checks passed. Apple accepted app submission `61a3d0b3-27de-4451-8cef-828ff093ba45` and DMG submission `13c7f824-762c-4d66-9e12-b4d72fd85fc3`. This is local release validation; the public 0.18.19 artifact will be built and published by the hosted workflow from the main merge.

The final **0.18.19** build is intentionally not installed by the agent: the user requested to test it through **Check for Updates**. Publication of the new source is managed by Bitrig, followed by the main-branch GitHub release workflow.

## Remaining findings and acceptance

| Priority | Status |
| --- | --- |
| Critical | No confirmed unresolved Critical defect in the reviewed scope. |
| High | The corrected hosted workflow's first complete run remains to be observed after Bitrig publishes the main merge. Local signing/notarization and the public Sparkle update path have passed; these do not substitute for that hosted-run result. |
| Medium | Opening a Bitrig simulator brings Bitrig forward; exact project selection still needs a documented host API. Bitrig also misclassifies the known Xcode metadata/destination warnings despite the underlying successful build. |
| Low | Live keyboard/VoiceOver and hover acceptance, macOS 14/Intel execution, launch-at-login, and watchOS/tvOS/visionOS runtime acceptance remain unverified on this Mac. Device-icon mapping is covered separately from launching those runtimes. |

The earlier process-termination, database protection, stale-data, LocalCan parsing, subprocess, and installer rollback fixes remain in place. This pass preserves the 340-point menu and does not add resource monitoring or change LocalCan routes.
