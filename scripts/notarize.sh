#!/bin/bash
# Firma con Developer ID + notarizza + staple Destroyer, per un DMG senza avvisi Gatekeeper.
# RICHIEDE un account Apple Developer ($99/anno) e le variabili qui sotto.
#
# Prerequisiti (una tantum):
#   1) Certificato "Developer ID Application" installato in Portachiavi.
#   2) Profilo notarytool salvato:
#        xcrun notarytool store-credentials NOTARY \
#          --apple-id "tuo@appleid.com" --team-id "XXXXXXXXXX" --password "app-specific-password"
#
# Uso:  DEV_ID="Developer ID Application: Nome (TEAMID)" scripts/notarize.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
: "${DEV_ID:?Imposta DEV_ID con la tua identità 'Developer ID Application: ...'}"
XCODEGEN="$(command -v xcodegen || echo /opt/homebrew/bin/xcodegen)"
VERSION="0.1.0"

echo "▶ Build Release…"
"$XCODEGEN" generate >/dev/null
xcodebuild -project Destroyer.xcodeproj -scheme Destroyer -configuration Release \
  -derivedDataPath build/dd build >/dev/null
APP="build/dd/Build/Products/Release/Destroyer.app"

echo "▶ Firma con Developer ID (Hardened Runtime già attivo)…"
codesign --force --deep --options runtime --timestamp \
  --entitlements App/Destroyer.entitlements --sign "$DEV_ID" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "▶ Creo il DMG…"
STAGE="build/dmg-stage"; rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
DMG="$HOME/Downloads/Destroyer-$VERSION.dmg"; rm -f "$DMG"
hdiutil create -volname "Destroyer" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

echo "▶ Notarizzazione (attendo l'esito)…"
xcrun notarytool submit "$DMG" --keychain-profile "NOTARY" --wait

echo "▶ Staple…"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
echo "✓ DMG notarizzato: $DMG"
