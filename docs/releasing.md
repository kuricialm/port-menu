# Automatic releases and in-app updates

Port Menu uses Sparkle. Updating GitHub source alone does not update an installed app: a release must be compiled, signed, notarized, and published first. The workflow in `.github/workflows/release.yml` performs that work for app changes on `main`, and can also be started manually on `main`.

## Local candidate awaiting user acceptance

**0.18.20** is a local test candidate on `fix-row-proportions`. It shares the main/database title component, bounds the database icon to the same marker size, moves database metadata to a second line, and uses the filled-square simulator stop icon. The Bitrig build, three layout tests, rendered fixture review, and copied-app signature check passed. The user explicitly requested local testing before release: do not merge or publish this candidate until they approve it. The public release remains 0.18.19.

## Normal workflow

1. Finish app changes on a feature branch and leave it selected. Bitrig publishes feature branches after the turn; it does not publish the default branch. Do not push manually from Bitrig.
2. Verify the feature commit exists on GitHub, then merge its reviewed pull request into remote `main`. Do not substitute a local merge into `main`: Bitrig explicitly leaves those commits unpublished.
3. GitHub Actions runs the tests, builds a universal Mac app, signs it with Developer ID, notarizes it with Apple, and creates a signed DMG and Sparkle feed.
4. Actions uploads all assets to a draft GitHub release, then publishes them together. Failed validation or uploads never expose a partial update through the feed.
5. Port Menu checks the fork feed hourly by default, verifies the signed feed and download, and downloads/installs updates using Sparkle. Users can change both update preferences in Settings or choose Check for Updates… immediately.

Sparkle can install downloaded updates when Port Menu quits. It may ask to relaunch or request macOS authorization; automatic updates do not bypass OS authorization. Stopping/relaunching Port Menu does not stop the servers or simulators it monitors.

The project version/build remains the starting point. The first public release advances the build number beyond the local bootstrap build, so the installed bootstrap build can receive it through Sparkle. If it is already published or behind the last release, Actions automatically advances the patch and build numbers in the release artifact. Deliberately higher versions are preserved. The release title and app Settings show only the release version, starting at 0.18.19; the internal build number still advances for Sparkle and macOS. Release notes identify the source commit. Actions does not commit generated versions back to the branch.

## Activation status — 11 September 2026

Developer ID signing is configured in this Mac's login Keychain: `Developer ID Application: Emad Alghamdi (D2WEKYD65B)`, certificate `F4GK7QPHN3`, expiring 11 September 2031. The existing Bitrig Apple credential authenticated and submitted accepted notarizations with its configured issuer. Keep that issuer: the configured credential is a team key.

All six encrypted repository secrets and both public variables below are saved in `kuricialm/port-menu` Actions settings. No private credential is stored in Git. The Mac retains the original signing keys in Keychain.

[Port Menu 0.8.17 (26)](https://github.com/kuricialm/port-menu/releases/tag/v0.8.17) is the first published fork release, built from immutable main commit `0cd04d179520fdcc5481b4f01fc48ed92df47d12`. Apple accepted both the app and DMG; stapling, Gatekeeper, universal slices, and Sparkle signatures passed. The public feed was fetched and verified independently.

The official Sparkle 2.9 CLI detected the update from the installed 0.8.17 (25), downloaded it from the public feed, verified it, installed 0.8.17 (26), and relaunched one app instance. A subsequent probe reported no newer update instead of a retrieval error. Onboarding and menu visibility were retained; automatic checks/install remain enabled with a 3,600-second interval. This exercises Sparkle's real replacement path, not the app's manual button or a timed hourly check.

The initial hosted run failed workflow validation because `runner.temp` is unavailable in job-level environment expressions. The fix initializes these paths in a runner step and passes official Actionlint 1.7.12. An incompatible `lipo -verify_arch` invocation was also replaced with exact architecture-token checks. The complete corrected release script passed locally for the notarized 0.8.18 typography build and the final 0.18.19 build, including app/DMG notarization, stapling, Gatekeeper, and signed-feed validation.

The first corrected [hosted release run](https://github.com/kuricialm/port-menu/actions/runs/34536377365) then passed and published [Port Menu 0.18.19](https://github.com/kuricialm/port-menu/releases/tag/v0.18.19), internal build 29, from immutable main commit `eb04433c0e87777ee8b23e6c5eff656ad28e3371`. Tests, signing, app/DMG notarization, feed validation, and publication all completed in GitHub Actions. The published DMG, appcast, and checksum file were downloaded independently and their hashes matched GitHub's asset digests. The official Sparkle CLI's read-only probe confirmed the update from the installed app; it did not install it.

The 0.18.19 source also rejects ordinary duplicate launches synchronously, before SwiftUI creates a menu scene. A live duplicate exited while the installed 0.8.18 stayed running alone; visibility remained true and no preferences changed. The final 0.18.19 update is reserved for the user’s manual Check for Updates test. See the [current release review](release-review-0.18.19.md).

### Publication follow-up

The next manual check still reported 0.8.17 because the new commits had not reached GitHub. Bitrig’s workspace notice explicitly says it does not publish a repository’s default branch. The prior local main merge therefore did not trigger a release. Moving the tested commits to `publish-update` let Bitrig publish them. After verifying the exact feature commit and app/build trees, [pull request #2](https://github.com/kuricialm/port-menu/pull/2) merged into remote main at `eb04433c0e87777ee8b23e6c5eff656ad28e3371`. That merge triggered the successful hosted 0.18.19 release above. GitHub Actions was the only publisher; no local publisher raced its release.

Bitrig rewrote the app commit from `cbe93f341d7ad58f04711fee3780b8854e5804e7` to `801d0d8`; their complete Git trees are identical. The later `220ec4e` commit changes only release documentation. The prepared local 0.18.19 app/DMG were rechecked: signatures, stapled tickets, Gatekeeper and universal architectures passed. These remained local validation artifacts. The public package was built separately by GitHub Actions from the verified remote main merge, with its own artifact hashes.

Configured in this repository's **Settings → Secrets and variables → Actions**:

| Kind | Name | Value |
| --- | --- | --- |
| Variable | `APPLE_TEAM_ID` | Your Apple Developer team, currently `D2WEKYD65B` for Bitrig builds; verify against the distribution certificate |
| Variable | `DEVELOPER_ID_APP` | Full `Developer ID Application: … (TEAMID)` identity |
| Secret | `DEVELOPER_ID_P12_BASE64` | Base64 of the exported Developer ID certificate **and its private key** in a password-protected `.p12` |
| Secret | `DEVELOPER_ID_P12_PASSWORD` | The `.p12` export password |
| Secret | `SPARKLE_PRIVATE_KEY` | The dedicated fork Sparkle key export described below |
| Secret | `NOTARY_API_PRIVATE_KEY` | Contents of the Apple notarization API `.p8` key |
| Secret | `NOTARY_KEY_ID` | Apple API key identifier |
| Secret | `NOTARY_ISSUER_ID` | Required for team keys, including the verified Bitrig credential; omit for individual API keys on Xcode 26+ |

Use a Developer ID Application certificate for direct Mac distribution, not an Apple Development, App Store, or installer certificate. Have the account holder create it if the Apple account role requires that. The notarization key must belong to the matching Apple team and have permission to submit apps. Do not paste private keys or certificate passwords in chat or commit them to Git. GitHub's hosted runner imports them into temporary protected files/keychain, and the cleanup step removes them even after failure.

### Dedicated Sparkle key

The fork key was created with Sparkle 2.9's `generate_keys --account kuricialm.port-menu`. Its private key remains in this Mac's Keychain. Its public key, embedded in the app, is:

```
0X1eQatxgbA81qc/hSYxzuVC/KfbQggxyF9uJthrBqw=
```

The configured `SPARKLE_PRIVATE_KEY` contains this exact fork key. For recovery or a new runner setup, export that specific account to protected temporary storage. Do not generate a different key: already-installed fork builds will trust the key above. Keep an encrypted backup of the original key.

The tools are in the **resolved build's** `SourcePackages/artifacts/sparkle/Sparkle/bin` directory. For example, after resolving dependencies into `/tmp/portmenu-packages`:

```sh
umask 077
PORTMENU_KEY_EXPORT=$(mktemp /tmp/portmenu-key.XXXXXX)
/tmp/portmenu-packages/artifacts/sparkle/Sparkle/bin/generate_keys \
  --account kuricialm.port-menu -x "$PORTMENU_KEY_EXPORT"
# With your own authenticated GitHub CLI, outside Bitrig's restricted app credentials:
gh secret set SPARKLE_PRIVATE_KEY --repo kuricialm/port-menu < "$PORTMENU_KEY_EXPORT"
rm -f "$PORTMENU_KEY_EXPORT"
```

Both the workflow and release script reject a private key that does not match the app's embedded public key before notarization. The previous feed's signature is checked before deriving the next version. Only `main` receives signing secrets; no pull-request workflow executes code with these credentials.

## First installation and identity

The release feed is `https://github.com/kuricialm/port-menu/releases/latest/download/appcast.xml`. The feed is live and signed. The checked-in `packaging/appcast.xml` remains an empty reference template, not the published feed. The earlier retrieval error occurred before the first fork release was published; no upstream fallback is used.

Install a build containing the fork channel once through Applications. The bootstrap 0.8.17 (25) has been successfully upgraded through Sparkle to the notarized 0.8.17 (26). Existing 0.8.14 and older builds still contain the upstream feed/key, so they cannot bootstrap the new fork channel automatically. Subsequent fork releases can update through Sparkle.

The bundle identifier `eduard.Porter` is deliberately retained for this existing installation so onboarding, launch-at-login identity, and other preferences remain associated with the same app. The fork replaces the upstream app at `/Applications/Port Menu.app`; simultaneous upstream/fork installation is not supported. The feed and EdDSA key are fork-owned, with signature checking required before extraction. Changing the bundle identifier later requires a separate migration.

## Local release and verification

With Developer ID and a `PortMenuNotary` notarization profile already in Keychain:

```sh
TEAM_ID="YOUR_TEAM_ID" \
DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)" \
./scripts/release-macos.sh
```

The script can also use `SPARKLE_KEY_FILE`, `NOTARY_API_KEY_FILE`, `NOTARY_KEY_ID`, and `NOTARY_ISSUER_ID`, as the workflow does. Team API keys require the issuer; individual API keys omit it and require Xcode 26 or later. The script rejects unsupported older notarization tools. `PACKAGES_DIR`, `OUTPUT_DIR`, and the paired `RELEASE_VERSION`/`RELEASE_BUILD` are optional overrides. It creates a unique temporary work directory and preserves it for diagnosis, rather than deleting existing output or mounted volumes.

Release validation includes signature verification, both arm64/x86_64 slices, notarization/stapling, Gatekeeper assessment, signing-key identity, fork-owned feed/download URLs, and matching app/feed version numbers. Keep dSYMs for crash reports.

Before calling the update channel accepted, publish two successive notarized fork builds and test an actual older-to-newer upgrade on a Mac, including relaunch and settings retention. Do not modify the installed app's Info.plist to fake an older version; that breaks its signature.

If a failed upload leaves a draft for the same source SHA, the next run safely resumes its uploads. A draft or tag belonging to different code is rejected without overwriting it. Published versions are immutable; rerunning an already published commit does nothing, and a commit older than or diverged from the latest release is rejected. For a bad public release, ship a corrected higher version rather than overwriting a signed artifact. A runner/toolchain failure leaves the last published release available.

## Sources

- [Sparkle setup and distribution](https://sparkle-project.org/documentation/)
- [Sparkle automatic update behavior](https://sparkle-project.org/documentation/customization/)
- [Official Sparkle command-line update validation](https://sparkle-project.org/documentation/sparkle-cli/)
- [GitHub Actions signing setup](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
