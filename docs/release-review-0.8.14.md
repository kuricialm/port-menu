# Port Menu 0.8.14 (22): pre-release review

Reviewed on 10 September 2026. Target: the current complete app on `local-urls-simulators`, including inherited upstream code and this fork's additions.

**Recommendation: hold public release until the three High findings are addressed.** No Critical issue was identified in this review. That is not a claim that the app is free of undiscovered defects.

The requested elapsed-time change is implemented separately from these findings. None of the unrelated findings below was silently fixed.

## Scope and evidence

Reviewed all Swift app sources, the test targets, Xcode project/scheme/entitlements, dependency lockfile, appcast, release script, and release documentation. Checks covered discovery, state refresh, termination actions, LocalCan routing, simulator actions, uptime, layout, accessibility code paths, installation, updates, and packaging.

- The optimized arm64 **Release configuration compiled successfully** on the macOS 27 SDK with signing disabled for that validation build.
- The local development app was installed as **0.8.14 (22)** in `/Applications/Port Menu.app`, with its signature verified and the previous version preserved. This was not a public release.
- The macOS app build completed successfully in Bitrig's underlying xcodebuild log. Bitrig's wrapper still reports failure with warnings; see the environment issue below.
- All **57 unit tests in 15 suites passed**, including simulator-session start parsing, reboot timing, minute/hour boundaries, device-set routing, and compact row layout.
- A live run of the actual scanner found **Piqly, iPhone 17 Pro Max, iOS 27.0**, with the boot-process start at **21:08:07 local time**. This matched `ps`; the timer is the simulated device session, not the app launch inside it.
- Inspected a rendered 340-point menu fixture with both elapsed-time labels on the existing second lines. Server elapsed time follows the branch; simulator elapsed time follows the device/runtime description. Timelines refresh at minute boundaries.
- Reproduced malformed-LocalCan-file failure and subprocess stderr backpressure using isolated temporary fixtures and disposable processes.
- Release and helper scripts passed shell/Ruby syntax checks. Public distribution, notarization, and update installation were not performed.

## Critical — 0 identified

No confirmed Critical issue was found in the reviewed scope. Destructive actions were examined in code; no real server or simulator was stopped to test failure cases.

## High — 3

### H1. The fork still updates and publishes through upstream's identity

**Evidence:** [PorterApp.swift](../Porter/PorterApp.swift), lines 4–7, returns the original author's appcast. The Xcode project retains the upstream `SUPublicEDKey` and bundle identifier. [release-macos.sh](../scripts/release-macos.sh), lines 179–205, generates upstream download/feed URLs and obtains a generic Sparkle signing key without checking it matches the app's embedded public key.

**Impact:** the fork cannot reliably deliver its own updates through the current configuration. A future eligible upstream update may offer to replace the customized app. Publishing this fork's DMG under its own repository also leaves generated update URLs pointing elsewhere; a mismatched signing key makes those updates fail verification.

**Fix:** choose a fork-owned update feed, release URL, and verified matching signing key, or disable update checks until that channel exists. Deliberately decide whether to retain the shared bundle identifier and preferences. Validate a complete update from an older fork build before release.

**Confidence:** confirmed configuration; no upstream update was installed during review.

### H2. A port's Kill action can target a shared Docker backend

**Evidence:** [PortScanning.swift](../Porter/PortScanning.swift), lines 269–299, explicitly accepts Docker/vpnkit backend processes. [PortStore.swift](../Porter/PortStore.swift), lines 119–131, sends `SIGTERM` directly to the recorded PID for both single and bulk termination, without distinguishing a backend from a dedicated server.

**Impact:** when Docker publishes a port through a shared backend PID, killing that row can interrupt multiple containers or Docker networking instead of just the displayed server.

**Fix:** classify shared owners and disable ordinary process-kill controls for them. If container-specific stopping is added later, resolve the exact container and use its own control mechanism. Revalidate process identity before any signal.

**Confidence:** confirmed code path; intentionally not tested by stopping Docker.

### H3. Failed self-installation does not restore the previous installation

**Evidence:** [AppHelpers.swift](../Porter/AppHelpers.swift), lines 81–95, moves the installed app to a backup before copying the replacement. The catch block only shows an error; it never restores that backup. Lines 88–92 remove the backup before confirming the new app launches successfully. Lines 100–114 start an unobserved shell process for relaunch/source cleanup.

**Impact:** a copy or move failure can leave `/Applications/Port Menu.app` missing while the usable copy is hidden under a backup name. A launch failure has no reliable automatic recovery.

**Fix:** validate the staged app before replacing the destination, restore the prior app on failure, retain the backup until launch is confirmed, and observe relaunch completion before removing the source.

**Confidence:** confirmed control flow; no fault was injected into the real Applications folder.

## Medium — 5

### M1. Failed termination is reported as success and can hide active servers

**Evidence:** [PortStore.swift](../Porter/PortStore.swift), lines 119–137, ignores the result of `kill`, records the port as killed, and logs success regardless. Lines 88–90 suppress all entries on that port for eight seconds. [Views.swift](../Porter/Views.swift), `killWithAnimation`, removes the row without waiting for confirmed termination.

**Impact:** permission failures, a process ignoring SIGTERM, or a quickly restarted server can leave a live service hidden and the active count understated.

**Fix:** check the signal result, show actionable errors, confirm process exit, and associate suppression with the original process identity rather than just the port.

**Confidence:** confirmed code path. Existing fake-PID tests currently encode the hiding behavior rather than verifying successful termination.

### M2. A failed port scan leaves apparently healthy, actionable stale rows

**Evidence:** [PortStore.swift](../Porter/PortStore.swift), lines 92–95, retains prior entries after failure. [Views.swift](../Porter/Views.swift), `PortMainContentView`, displays its scan error only when entries are empty. [PorterApp.swift](../Porter/PorterApp.swift), lines 61–65, keeps the indicator green when any item remains.

**Impact:** a stalled or repeatedly failing scanner can leave an old count and old process actions looking current. Reusing an old PID for termination is especially undesirable.

**Fix:** show a stale/error indication while retaining useful last-known data, expose the last successful scan time, and revalidate a process before destructive actions.

**Confidence:** confirmed state/UI conditions.

### M3. One malformed LocalCan project removes every valid local URL

**Evidence:** [LocalCanRoutes.swift](../Porter/LocalCanRoutes.swift), lines 12–29, parses every file in one Ruby process without per-file recovery. [DevelopmentServices.swift](../Porter/DevelopmentServices.swift), lines 30–31, clears the full route map on failure.

**Reproduction:** an isolated valid project returned `{"3210":["https://example.local"]}`. Adding an unrelated malformed YAML project made the same reader exit 1 with no route output.

**Impact:** all `.local` actions disappear because of one unrelated project or a file caught during an edit.

**Fix:** validate and isolate errors per file/service, preserve valid routes, and report which configuration could not be read. Keep all LocalCan access read-only.

### M4. Subprocesses can block on stderr and become false timeouts

**Evidence:** [PortScanning.swift](../Porter/PortScanning.swift), lines 392–399, drains stdout to EOF before reading stderr. A child that fills the stderr pipe blocks before it can finish.

**Reproduction:** the actual runner completed a disposable command writing 100 stderr bytes; the otherwise equivalent command writing 512,000 bytes failed with “Port scan timed out” at roughly 1.14 seconds with a one-second deadline.

**Impact:** valid discovery/action commands can fail under verbose error output. The timeout path also relies on SIGTERM, so a child that ignores that signal can exceed the advertised deadline; that additional case was identified in code, not exercised.

**Fix:** drain both streams concurrently using nonblocking/background I/O, retain a bounded useful stderr message, and make cancellation/deadline handling complete reliably for child processes the app created.

### M5. Show in Bitrig cannot select the specific simulator project

**Evidence:** [DevelopmentServices.swift](../Porter/DevelopmentServices.swift), lines 45–48, opens the Bitrig bundle with no device or project identifier.

**Impact:** with several Bitrig projects/simulators open, every row performs the same host activation. It may bring forward a different project from the selected simulator. The current tooltip accurately says “Show in Bitrig,” but per-device focus remains incomplete.

**Fix:** use a documented Bitrig project/device activation mechanism if available. Until then, retain the explicit host-level label and treat exact project focus as unsupported rather than claiming it works.

**Confidence:** confirmed command limitation; no undocumented Bitrig URL was invented or used.

## Low — 3

### L1. Some valid development ports are silently excluded

[PortScanning.swift](../Porter/PortScanning.swift), lines 110–115, ignores ports below 1024 and at or above 49152. A development server on port 55000 therefore cannot appear or contribute to the count. Prefer identifying development processes without this upper cutoff, or clearly document/configure the supported range.

### L2. “Kill all” has an ambiguous scope beside the combined count

[Views.swift](../Porter/Views.swift), lines 148–154, puts “Kill all” in the global header, but [PortStore.swift](../Porter/PortStore.swift), `killAllProcesses`, affects only port processes. The badge now includes simulators. Clarify the action as “Kill ports” or add an equally explicit tooltip/accessibility label; do not silently expand its destructive scope.

### L3. Accessibility needs a focused finish

The Settings and Quit header buttons in [Views.swift](../Porter/Views.swift), lines 158–169, lack explicit purpose-based accessibility labels; custom visual tooltips are separate views. [Onboarding.swift](../Porter/Onboarding.swift) and the empty-state/exit animations in Views do not honor Reduce Motion, although the new row-action reveal does. Add purpose labels and reduced-motion alternatives while preserving the normal animation style. Verify keyboard focus and VoiceOver on a real menu; source inspection alone does not establish acceptance.

## Release workflow and remaining verification

- **External Bitrig issue:** its build tool repeatedly returned `failure` although the build log said `BUILD SUCCEEDED`. Its Install to Applications flow previously left Applications unchanged. This is separate from the app's own installer in H3. A signature-verified direct local installation has been the workaround; the Bitrig issue still needs its own report/fix.
- The release script locates `sign_update` by scanning the default Xcode DerivedData directory (line 179), rather than the actual build's resolved Sparkle tools. Validate that path and the signing-key/public-key match at the start of the fork's release workflow, before spending time notarizing.
- The UI-test target has no substantive test cases. The passing 57-test suite includes hosted layout checks but does not prove live hover motion, keyboard/VoiceOver behavior, launch-at-login, real termination, or update installation.
- The installed app's first-run update dialog has previously blocked live menu inspection while awaiting the user's preference; no automatic-update preference was changed for this review.
- Intel, macOS 14, watchOS/tvOS/visionOS runtimes, multi-project simulator focus, Developer ID notarization/stapling, and clean-machine installation have not been validated in this review. Do not describe the local development build as a notarized public release.
- This was a source and behavior review, not an exhaustive third-party dependency vulnerability audit or penetration test.

## Suggested fix order

1. Establish the fork's safe update/release identity (H1).
2. Correct destructive targeting and termination feedback (H2, M1, M2).
3. Make installation rollback reliable (H3).
4. Isolate LocalCan failures and fix subprocess I/O (M3, M4).
5. Resolve/document exact simulator focus, finish accessibility, and perform the outstanding release-device checks.
