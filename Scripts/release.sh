#!/usr/bin/env bash
# Build, sign, and notarize a Developer ID release of PromptMeter, then
# produce a .zip ready for upload to a GitHub Release / Homebrew Cask.
#
# Usage:
#   APPLE_ID=you@example.com \
#   APPLE_TEAM_ID=9VGW4UAWY2 \
#   APPLE_APP_PASSWORD='xxxx-xxxx-xxxx-xxxx' \
#   Scripts/release.sh 0.1.0
#
# Prerequisites:
#   - Xcode with the active Developer ID Application certificate in the login keychain.
#   - The PromptMeter target uses Hardened Runtime (Xcode does this by default
#     when you select Developer ID signing).
#   - notarytool credentials: an Apple ID, the team ID, and an app-specific
#     password generated at https://appleid.apple.com → App-Specific Passwords.
#
# Output:
#   build/PromptMeter-<version>.zip   – notarized, stapled, ready to ship.
#   The script prints the SHA256 you need for Homebrew Cask.

set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>" >&2
    echo "Example: $0 0.1.0" >&2
    exit 1
fi

: "${APPLE_ID:?APPLE_ID env var required}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID env var required}"
: "${APPLE_APP_PASSWORD:?APPLE_APP_PASSWORD env var required}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/PromptMeter.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_PATH="$EXPORT_DIR/PromptMeter.app"
ZIP_PATH="$BUILD_DIR/PromptMeter-$VERSION.zip"
EXPORT_OPTIONS="$ROOT_DIR/ExportOptions.plist"

cd "$ROOT_DIR"

if [[ ! -f "$EXPORT_OPTIONS" ]]; then
    echo "❌ Missing $EXPORT_OPTIONS" >&2
    exit 1
fi

echo "▶︎ Cleaning $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "▶︎ Archiving PromptMeter (Release, Developer ID)"
xcodebuild \
    -project PromptMeter.xcodeproj \
    -scheme PromptMeter \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=macOS' \
    archive

echo "▶︎ Exporting .app from archive"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_DIR"

if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ Export did not produce $APP_PATH" >&2
    exit 1
fi

echo "▶︎ Zipping .app for notarytool"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "▶︎ Submitting to Apple notarization service (this can take a few minutes)"
xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait

echo "▶︎ Stapling notarization ticket onto PromptMeter.app"
xcrun stapler staple "$APP_PATH"

echo "▶︎ Re-zipping the stapled .app for distribution"
rm "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
SIZE=$(du -h "$ZIP_PATH" | awk '{print $1}')

echo ""
echo "✅ Release artifact ready"
echo "    Path:    $ZIP_PATH"
echo "    Size:    $SIZE"
echo "    Version: $VERSION"
echo "    SHA256:  $SHA256"
echo ""
echo "Next steps:"
echo "  1. gh release create v$VERSION \"$ZIP_PATH\" --title \"v$VERSION\" --generate-notes"
echo "  2. In your homebrew-tap repo, update Casks/promptmeter.rb:"
echo "       version \"$VERSION\""
echo "       sha256 \"$SHA256\""
