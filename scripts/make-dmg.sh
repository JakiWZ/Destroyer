#!/bin/bash
# Genera build Release + DMG di Destroyer in ~/Downloads, in un comando.
# Uso: scripts/make-dmg.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="0.1.0"
XCODEGEN="$(command -v xcodegen || echo /opt/homebrew/bin/xcodegen)"

echo "▶ Rigenero il progetto Xcode…"
"$XCODEGEN" generate >/dev/null

echo "▶ Build Release…"
xcodebuild -project Destroyer.xcodeproj -scheme Destroyer -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build/dd build \
  >/dev/null

APP="build/dd/Build/Products/Release/Destroyer.app"
[ -d "$APP" ] || { echo "✗ App non trovata: $APP"; exit 1; }

echo "▶ Preparo il DMG…"
STAGE="build/dmg-stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

DMG="$HOME/Downloads/Destroyer-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Destroyer" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

rm -rf "$STAGE"
echo "✓ Creato: $DMG"
ls -lh "$DMG"
