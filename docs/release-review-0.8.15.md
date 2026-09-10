# Port Menu 0.8.15 (23): review fixes and release readiness

10 September 2026. Follow-up to [the 0.8.14 review](release-review-0.8.14.md).

The code fixes are implemented and the development build is installed in `/Applications/Port Menu.app`. The original 340-point layout, two-line rows, uptime placement, hover controls, and normal button motion are retained. Public automatic delivery is prepared but is **not activated or accepted end to end** until distribution credentials are configured and releases are published.

## Findings status

| Priority / ID | Status | Result |
| --- | --- | --- |
| Critical | None identified | No confirmed Critical finding in the reviewed scope. |
| High H1 — upstream updates | Fixed in app/configuration; distribution setup pending | Fork-owned HTTPS feed and dedicated EdDSA key. Signed feeds/download verification required. Actual app inspection found Xcode omitted the old arbitrary `INFOPLIST_KEY_SU…` settings; explicit `packaging/Info.plist` now embeds them, and a built-app regression test enforces this. Existing bundle identifier/preferences deliberately retained. |
| High H2 — shared Docker termination | Fixed | Docker/vpnkit rows remain visible but cannot receive ordinary stop signals. Both cached and current process ownership are checked. |
| High H3 — installer rollback | Fixed | Copy and signature validation precede replacement. Swap/launch failures restore the old installation. Recovery failures preserve and identify the backup. Launch completion precedes cleanup; source is retained. |
| Medium M1 — false termination success | Fixed | Verify current listener and kernel PID/start identity, check the signal result, and wait for exit. Permission errors, ignored SIGTERM, and restarts remain visible. No port-wide suppression or optimistic removal. |
| Medium M2 — stale rows | Fixed | Visible stale warning, last scan time, Retry, orange badge/row status, and accessibility status. Stopping is disabled until a successful refresh. |
| Medium M3 — malformed LocalCan config | Fixed | Recover per file/service/endpoint, retain valid neighbors, and report affected configuration names. No configuration writes. |
| Medium M4 — subprocess blocking | Fixed | Concurrent nonblocking stdout/stderr drains, bounded buffers, cancellation/deadline handling, and controlled cleanup of owned command processes. |
| Medium M5 — exact Bitrig project focus | Mitigated; host capability unresolved | Action explicitly says Open Bitrig, including the context menu. No documented per-project/device activation API was found in exposed Bitrig tools/guidance or public docs. It brings the host forward; exact project selection is not claimed. |
| Low L1 — excluded port ranges | Fixed | Development listeners can be discovered across valid ports 1–65535. |
| Low L2 — ambiguous bulk action | Fixed | Header says Kill ports, describes eligible servers, and excludes shared backends and simulators. |
| Low L3 — accessibility | Code fixes complete; assistive UI acceptance pending | Settings/Quit labels, stale badge description, reduced-motion onboarding/empty/row exit/list reflow, and observed updater controls. Normal motion preserved. |

Also corrected percent-encoded filesystem paths in Git repository discovery and self-installation. Repositories with spaces and Arabic names now have regression coverage. Onboarding's cancelled animation sequence no longer continues detached tasks. Update checks are disabled in the test host.

## Verification completed

- **87 app tests in 21 suites passed**, including termination failure/reuse/restart cases, malformed route isolation, large stdout/stderr, cancellation and ignored TERM, eight installer fault cases, compact layout, simulator sessions, repository paths, and the built app's actual updater identity/settings.
- **7 release automation tests passed**, covering version progression, foreign feed rejection, stale/diverged source rejection, matching-draft retries, public-release collision protection, and failed uploads remaining unpublished.
- Both **arm64 and x86_64 Release slices compiled successfully** on the macOS 27 SDK; `lipo` confirmed both architectures. This is compilation, not Intel runtime acceptance.
- Bitrig's underlying final app build log says **BUILD SUCCEEDED**. Its wrapper still reports failure for AppIntents metadata and ambiguous-destination warnings. This external Bitrig reporting/install issue is not fixed by app changes.
- The development-signed **0.8.15 (23)** app's signature was verified outside the restricted shell, installed in Applications, and its running process confirmed. The previous 0.8.14 copy is preserved under a unique `/private/tmp/Port Menu.backup-0.8.14-22-….app` path.
- A local update DMG was created from the actual signed app; Sparkle's `generate_appcast` generated and signed its feed with the fork Keychain key. `sign_update --verify` and the fork URL/version validator passed. This disposable archive was **not notarized or published**.
- The actual simulator scanner still finds **Piqly / iPhone 17 Pro Max / iOS 27.0** in Bitrig's custom device set, with the correct session start time.
- A disposable loopback listener was stopped through the production process terminator. No user server, Docker backend, or simulator was shut down during verification.
- The rendered 340-point Stock/Piqly fixture preserves two-line rows, elapsed-time placement, and content height. Native automation timed out when inspecting the running menu-only app, so live keyboard/VoiceOver and hover acceptance are not claimed.
- Shell/YAML syntax checks and `git diff --check` passed.

## Remaining release work, by priority

| Priority | Remaining work |
| --- | --- |
| Critical | None confirmed. |
| High | Add a Developer ID Application certificate and notarization credentials to GitHub Actions, plus the existing fork Sparkle key; then publish and verify a real older-to-newer notarized update. The Mac currently has only Apple Development signing. Bitrig's GitHub App cannot manage Actions secrets (HTTP 403). See [setup instructions](releasing.md). |
| Medium | Exact Bitrig project activation needs a supported Bitrig API. Bitrig's false build-failure/install reporting remains an external tool issue. |
| Low | Complete live keyboard/VoiceOver, macOS 14/Intel runtime, launch-at-login, and watchOS/tvOS/visionOS acceptance on available devices/runtimes. |

The release workflow runs only trusted main commits, advances version/build numbers, verifies signatures, and uploads into a draft before publishing. It resumes only a draft belonging to the same source SHA, refuses conflicting tags/public assets, skips an already released commit, and rejects older/diverged source. Feature-branch commits do not publish public app updates. No GitHub push, merge, public release, credential export, or repository-secret write was performed in this work.
