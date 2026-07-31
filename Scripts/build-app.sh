#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="$ROOT/dist/Scribe.app"
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
BIN_DIR=$(swift build -c release --show-bin-path)
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"
cp "$BIN_DIR/Scribe" "$APP/Contents/MacOS/Scribe"
LAME_FRAMEWORK=$(find "$ROOT/.build/artifacts" \
  -path '*/LAME.xcframework/macos-arm64_x86_64/LAME.framework' \
  -type d \
  | head -n 1)
if [ -z "$LAME_FRAMEWORK" ]; then
  echo "Could not find the built LAME framework."
  exit 1
fi
cp -R "$LAME_FRAMEWORK" "$APP/Contents/Frameworks/LAME.framework"
install_name_tool \
  -add_rpath '@executable_path/../Frameworks' \
  "$APP/Contents/MacOS/Scribe"
LAME_LICENSE_ROOT="$ROOT/.build/checkouts/LAME-xcframework"
mkdir -p "$APP/Contents/Resources/ThirdPartyLicenses/LAME"
cp "$LAME_LICENSE_ROOT/LICENSE" "$APP/Contents/Resources/ThirdPartyLicenses/LAME/"
cp "$LAME_LICENSE_ROOT/LICENSE-LAME" "$APP/Contents/Resources/ThirdPartyLicenses/LAME/"
cp "$LAME_LICENSE_ROOT/COPYING" "$APP/Contents/Resources/ThirdPartyLicenses/LAME/"
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
