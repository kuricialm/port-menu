# Automatic releases and in-app updates

Port Menu uses Sparkle. Updating GitHub source alone does not update an installed app: a release must be compiled, signed, notarized, and published first. The workflow in `.github/workflows/release.yml` performs that work for app changes on `main`, and can also be started manually on `main`.

## Normal workflow

1. Finish app changes on a feature branch. Bitrig publishes commits; do not push manually from Bitrig.
2. Merge the reviewed changes into `main`.
3. GitHub Actions runs the tests, builds a universal Mac app, signs it with Developer ID, notarizes it with Apple, and creates a signed DMG and Sparkle feed.
4. Actions uploads all assets to a draft GitHub release, then publishes them together. Failed validation or uploads never expose a partial update through the feed.
5. Port Menu checks the fork feed hourly by default, verifies the signed feed and download, and downloads/installs updates using Sparkle. Users can change both update preferences in Settings or choose Check for Updates… immediately.

Sparkle can install downloaded updates when Port Menu quits. It may ask to relaunch or request macOS authorization; automatic updates do not bypass OS authorization. Stopping/relaunching Port Menu does not stop the servers or simulators it monitors.

The project version/build remains the starting point. The first public release advances the build number beyond the local bootstrap build, so the newly installed 0.8.15 (23) can receive it through Sparkle. If it is already published or behind the last release, Actions automatically advances the patch and build numbers in the release artifact. Deliberately higher versions are preserved. The release title and app Settings show the actual version/build; release notes identify the source commit. Actions does not commit generated versions back to the branch.

## One-time setup still required

As checked on 10 September 2026, this Mac has an Apple Development certificate, but no Developer ID Application identity. Bitrig's GitHub App credentials cannot access Actions secrets (GitHub returned HTTP 403). No public release or in-app update installation has been performed. The workflow stops with a named missing-setting error until configured.

In this repository's **Settings → Secrets and variables → Actions**, configure:

| Kind | Name | Value |
| --- | --- | --- |
| Variable | `APPLE_TEAM_ID` | Your Apple Developer team, currently `D2WEKYD65B` for Bitrig builds; verify against the distribution certificate |
| Variable | `DEVELOPER_ID_APP` | Full `Developer ID Application: … (TEAMID)` identity |
| Secret | `DEVELOPER_ID_P12_BASE64` | Base64 of the exported Developer ID certificate **and its private key** in a password-protected `.p12` |
| Secret | `DEVELOPER_ID_P12_PASSWORD` | The `.p12` export password |
| Secret | `SPARKLE_PRIVATE_KEY` | The dedicated fork Sparkle key export described below |
| Secret | `NOTARY_API_PRIVATE_KEY` | Contents of the Apple notarization API `.p8` key |
| Secret | `NOTARY_KEY_ID` | Apple API key identifier |
| Secret | `NOTARY_ISSUER_ID` | Apple API issuer identifier |

Use a Developer ID Application certificate for direct Mac distribution, not an Apple Development, App Store, or installer certificate. Have the account holder create it if the Apple account role requires that. The notarization key must belong to the matching Apple team and have permission to submit apps. Do not paste private keys or certificate passwords in chat or commit them to Git. GitHub's hosted runner imports them into temporary protected files/keychain, and the cleanup step removes them even after failure.

### Dedicated Sparkle key

The fork key was created with Sparkle 2.9's `generate_keys --account kuricialm.port-menu`. Its private key remains in this Mac's Keychain. Its public key, embedded in the app, is:

```
0X1eQatxgbA81qc/hSYxzuVC/KfbQggxyF9uJthrBqw=
```

Once you have a GitHub login that can manage repository secrets, export that specific account to a protected temporary file and use it as `SPARKLE_PRIVATE_KEY`. Do not generate a different key: already-installed fork builds will trust the key above. Keep an encrypted backup of the original key.

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

The release feed is `https://github.com/kuricialm/port-menu/releases/latest/download/appcast.xml`. The checked-in `packaging/appcast.xml` is an empty reference template, not a live published feed. Before the first release exists, manual checks can report a feed/download error; no upstream fallback is used.

Install a build containing the fork channel once through Applications; 0.8.15 (23) is already installed on this Mac. Existing 0.8.14 and older builds still contain the upstream feed/key, so they cannot bootstrap the new fork channel automatically. Subsequent fork releases can update through Sparkle.

The bundle identifier `eduard.Porter` is deliberately retained for this existing installation so onboarding, launch-at-login identity, and other preferences remain associated with the same app. The fork replaces the upstream app at `/Applications/Port Menu.app`; simultaneous upstream/fork installation is not supported. The feed and EdDSA key are fork-owned, with signature checking required before extraction. Changing the bundle identifier later requires a separate migration.

## Local release and verification

With Developer ID and a `PortMenuNotary` notarization profile already in Keychain:

```sh
TEAM_ID="YOUR_TEAM_ID" \
DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)" \
./scripts/release-macos.sh
```

The script can also use `SPARKLE_KEY_FILE`, `NOTARY_API_KEY_FILE`, `NOTARY_KEY_ID`, and `NOTARY_ISSUER_ID`, as the workflow does. `PACKAGES_DIR`, `OUTPUT_DIR`, and the paired `RELEASE_VERSION`/`RELEASE_BUILD` are optional overrides. It creates a unique temporary work directory and preserves it for diagnosis, rather than deleting existing output or mounted volumes.

Release validation includes signature verification, both arm64/x86_64 slices, notarization/stapling, Gatekeeper assessment, signing-key identity, fork-owned feed/download URLs, and matching app/feed version numbers. Keep dSYMs for crash reports.

Before calling the update channel accepted, publish two successive notarized fork builds and test an actual older-to-newer upgrade on a Mac, including relaunch and settings retention. Do not modify the installed app's Info.plist to fake an older version; that breaks its signature.

If a failed upload leaves a draft for the same source SHA, the next run safely resumes its uploads. A draft or tag belonging to different code is rejected without overwriting it. Published versions are immutable; rerunning an already published commit does nothing, and a commit older than or diverged from the latest release is rejected. For a bad public release, ship a corrected higher version rather than overwriting a signed artifact. A runner/toolchain failure leaves the last published release available.

## Sources

- [Sparkle setup and distribution](https://sparkle-project.org/documentation/)
- [Sparkle automatic update behavior](https://sparkle-project.org/documentation/customization/)
- [GitHub Actions signing setup](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
