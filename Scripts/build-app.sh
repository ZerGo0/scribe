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
if otool -L "$APP/Contents/MacOS/Scribe" | grep -q libswiftCompatibilitySpan; then
  SPAN_LIBRARY=$(find "$(dirname "$(xcrun --find swift)")/../lib" \
    -path '*/macosx/libswiftCompatibilitySpan.dylib' \
    | head -n 1)
  if [ -z "$SPAN_LIBRARY" ]; then
    echo "Could not find libswiftCompatibilitySpan.dylib."
    exit 1
  fi
  cp "$SPAN_LIBRARY" "$APP/Contents/Frameworks/"
fi
for RESOURCE_BUNDLE in "$BIN_DIR"/*.bundle; do
  [ -d "$RESOURCE_BUNDLE" ] || continue
  cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
done
LICENSES="$APP/Contents/Resources/ThirdPartyLicenses"
for CHECKOUT in "$ROOT"/.build/checkouts/*; do
  NAME=$(basename "$CHECKOUT")
  for LICENSE_FILE in "$CHECKOUT"/LICENSE* "$CHECKOUT"/COPYING* "$CHECKOUT"/NOTICE*; do
    [ -f "$LICENSE_FILE" ] || continue
    mkdir -p "$LICENSES/$NAME"
    cp "$LICENSE_FILE" "$LICENSES/$NAME/"
  done
done
cp "$ROOT/.build/checkouts/FluidAudio/ThirdPartyLicenses/fastcluster-LICENSE.md" "$LICENSES/FluidAudio/"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if ! xcrun actool \
  --compile "$APP/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target 15.0 \
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
