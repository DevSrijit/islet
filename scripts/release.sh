#!/bin/zsh
# Builds a Release app, signs it ad hoc, and zips it into dist/.
# Usage: scripts/release.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' project.yml | head -1)}"
DERIVED="build/DerivedData"
DIST="dist"
APP="$DERIVED/Build/Products/Release/Islet.app"

xcodegen generate >/dev/null
xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Release \
  -derivedDataPath "$DERIVED" build CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES | grep -E "error:|BUILD" || true

test -d "$APP" || { echo "Build failed: $APP is missing"; exit 1; }
codesign --force --deep --sign - "$APP"

mkdir -p "$DIST"
ZIP="$DIST/Islet-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP" | tee "$ZIP.sha256"
echo "Built $ZIP"
