#!/bin/zsh
# A release is published only by the workflow after this script verifies it.
set -euo pipefail
umask 077
: "${TEAM_ID:?Set TEAM_ID}"
: "${DEVELOPER_ID_APP:?Set a Developer ID Application identity}"
[[ "$DEVELOPER_ID_APP" == 'Developer ID Application:'* ]] || { print -u2 'A development certificate cannot sign a public release.'; exit 1; }
ROOT="${0:A:h:h}"
cd "$ROOT"
RELEASE_REPOSITORY="kuricialm/port-menu"
FEED_URL="https://github.com/${RELEASE_REPOSITORY}/releases/latest/download/appcast.xml"
SPARKLE_ACCOUNT="kuricialm.port-menu"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"
mkdir -p "$OUTPUT_DIR"
# Unique work directory: never delete an existing build or mounted volume.
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/portmenu-release.XXXXXX")
DERIVED_DATA="$WORK_DIR/DerivedData"
PACKAGES_DIR="${PACKAGES_DIR:-$WORK_DIR/SourcePackages}"
ARCHIVE_PATH="$WORK_DIR/PortMenu.xcarchive"
APP_PATH="$WORK_DIR/export/Port Menu.app"
print "Release work directory: $WORK_DIR"
xcodebuild -resolvePackageDependencies -project Porter.xcodeproj -scheme Porter \
  -clonedSourcePackagesDirPath "$PACKAGES_DIR" -onlyUsePackageVersionsFromResolvedFile
SPARKLE_BIN="$PACKAGES_DIR/artifacts/sparkle/Sparkle/bin"
[[ -x "$SPARKLE_BIN/generate_appcast" ]] || { print -u2 'Resolved Sparkle tools missing.'; exit 1; }
EXPECTED_KEY=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' packaging/Info.plist)
SIGNING_ARGS=(--account "$SPARKLE_ACCOUNT")
if [[ -n "${SPARKLE_KEY_FILE:-}" ]]; then
  ACTUAL_KEY=$(xcrun swift scripts/sparkle-public-key.swift "$SPARKLE_KEY_FILE")
  SIGNING_ARGS=(--ed-key-file "$SPARKLE_KEY_FILE")
else
  ACTUAL_KEY=$("$SPARKLE_BIN/generate_keys" --account "$SPARKLE_ACCOUNT" -p)
fi
[[ "$EXPECTED_KEY" == "$ACTUAL_KEY" ]] || { print -u2 'Sparkle key does not match the app. Release stopped.'; exit 1; }
VERSION_ARGS=()
if [[ -n "${RELEASE_VERSION:-}" && -n "${RELEASE_BUILD:-}" ]]; then
  [[ "$RELEASE_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' && "$RELEASE_BUILD" =~ '^[1-9][0-9]*$' ]] || exit 1
  VERSION_ARGS=("MARKETING_VERSION=$RELEASE_VERSION" "CURRENT_PROJECT_VERSION=$RELEASE_BUILD")
fi
xcodebuild archive -project Porter.xcodeproj -scheme Porter -configuration Release \
  -archivePath "$ARCHIVE_PATH" -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$PACKAGES_DIR" -onlyUsePackageVersionsFromResolvedFile \
  -destination 'generic/platform=macOS' ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_IDENTITY="$DEVELOPER_ID_APP" \
  "${VERSION_ARGS[@]}"
# Exporting the archive signs Sparkle's nested helpers correctly; no ignored signing failures.
TEAM_ID="$TEAM_ID" DEVELOPER_ID_APP="$DEVELOPER_ID_APP" WORK_DIR="$WORK_DIR" python3 - <<'PY'
import os, plistlib
with open(os.environ['WORK_DIR']+'/ExportOptions.plist', 'wb') as f:
    plistlib.dump({'method':'developer-id', 'teamID':os.environ['TEAM_ID'],
                  'signingStyle':'manual', 'signingCertificate':os.environ['DEVELOPER_ID_APP']}, f)
PY
xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" -exportPath "$WORK_DIR/export" \
  -exportOptionsPlist "$WORK_DIR/ExportOptions.plist"
codesign --verify --deep --strict "$APP_PATH"
APP_ARCHITECTURES=$(lipo -archs "$APP_PATH/Contents/MacOS/Port Menu")
for REQUIRED_ARCH in arm64 x86_64; do
  case " $APP_ARCHITECTURES " in
    *" $REQUIRED_ARCH "*) ;;
    *) print -u2 "Release app is missing required architecture: $REQUIRED_ARCH"; exit 1 ;;
  esac
done
[[ $(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP_PATH/Contents/Info.plist") == "$EXPECTED_KEY" ]] || exit 1
[[ $(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$APP_PATH/Contents/Info.plist") == "$FEED_URL" ]] || exit 1
NOTARY_AUTH_ARGS=(--keychain-profile "${NOTARY_PROFILE:-PortMenuNotary}")
if [[ -n "${NOTARY_API_KEY_FILE:-}" ]]; then
  : "${NOTARY_KEY_ID:?Set NOTARY_KEY_ID}"
  NOTARY_AUTH_ARGS=(--key "$NOTARY_API_KEY_FILE" --key-id "$NOTARY_KEY_ID")
  if [[ -n "${NOTARY_ISSUER_ID:-}" ]]; then
    NOTARY_AUTH_ARGS+=(--issuer "$NOTARY_ISSUER_ID")
  else
    # Individual keys use the user's identity; supplying an issuer causes HTTP 401.
    NOTARY_HELP=$(xcrun notarytool submit --help)
    [[ "$NOTARY_HELP" == *'Individual API Keys'* ]] || {
      print -u2 'Individual notarization API keys require notarytool from Xcode 26 or later.'
      exit 1
    }
  fi
fi
notarize() {
  xcrun notarytool submit "$1" "${NOTARY_AUTH_ARGS[@]}" --wait
}
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$WORK_DIR/notarize.zip"
notarize "$WORK_DIR/notarize.zip"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute "$APP_PATH"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")
ASSET="PortMenu-${VERSION}.dmg"
mkdir -p "$WORK_DIR/staging" "$WORK_DIR/updates"
/usr/bin/ditto "$APP_PATH" "$WORK_DIR/staging/Port Menu.app"
ln -s /Applications "$WORK_DIR/staging/Applications"
# Headless DMG creation works in GitHub Actions without controlling Finder.
hdiutil create -volname 'Port Menu' -srcfolder "$WORK_DIR/staging" -format UDZO "$WORK_DIR/updates/$ASSET"
codesign --sign "$DEVELOPER_ID_APP" --timestamp "$WORK_DIR/updates/$ASSET"
notarize "$WORK_DIR/updates/$ASSET"
xcrun stapler staple "$WORK_DIR/updates/$ASSET"
xcrun stapler validate "$WORK_DIR/updates/$ASSET"
codesign --verify "$WORK_DIR/updates/$ASSET"
spctl --assess --type open --context context:primary-signature "$WORK_DIR/updates/$ASSET"
"$SPARKLE_BIN/generate_appcast" "${SIGNING_ARGS[@]}" --maximum-deltas 0 \
  --download-url-prefix "https://github.com/${RELEASE_REPOSITORY}/releases/download/v${VERSION}/" \
  --link "https://github.com/${RELEASE_REPOSITORY}" "$WORK_DIR/updates"
"$SPARKLE_BIN/sign_update" "${SIGNING_ARGS[@]}" --verify "$WORK_DIR/updates/appcast.xml"
python3 scripts/release-metadata.py validate "$WORK_DIR/updates/appcast.xml" "$VERSION" "$BUILD"
cp "$WORK_DIR/updates/$ASSET" "$WORK_DIR/updates/appcast.xml" "$OUTPUT_DIR/"
(cd "$OUTPUT_DIR"; shasum -a 256 "$ASSET" appcast.xml > SHA256SUMS)
/usr/bin/ditto "$ARCHIVE_PATH/dSYMs" "$OUTPUT_DIR/dSYMs"
print "Verified release: $VERSION ($BUILD), artifacts in $OUTPUT_DIR"
