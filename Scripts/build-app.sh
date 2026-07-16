#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="$ROOT/dist/ZerGo0Scribe.app"
SIGNING_IDENTITY=${CODE_SIGN_IDENTITY:-}

if [ -z "$SIGNING_IDENTITY" ]; then
  SIGNING_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\([^"]*\)".*/\1/p' \
    | head -n 1)
fi

if [ -z "$SIGNING_IDENTITY" ]; then
  SIGNING_IDENTITY=-
fi

cd "$ROOT"
swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/ZerGo0Scribe" "$APP/Contents/MacOS/ZerGo0Scribe"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if ! xcrun actool \
  --compile "$APP/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --standalone-icon-behavior all \
  --output-partial-info-plist "$ROOT/.build/AppIcon-Info.plist" \
  --warnings \
  --errors \
  "$ROOT/Resources/AppIcon.icon" \
  > "$ROOT/.build/AppIcon-actool-output.plist"; then
  echo "Could not compile the app icon."
  plutil -p "$ROOT/.build/AppIcon-actool-output.plist" || true
  exit 1
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP"
swift "$ROOT/Scripts/verify-app-icon.swift" \
  "$APP" \
  "$ROOT/.build/AppIconPreview.png"
printf 'Built %s\n' "$APP"
