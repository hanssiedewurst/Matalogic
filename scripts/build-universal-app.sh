#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

rm -rf .build-arm64 .build-x86_64 dist

swift build -c release --arch arm64 --scratch-path "$ROOT/.build-arm64"
swift build -c release --arch x86_64 --scratch-path "$ROOT/.build-x86_64"

ARM_BIN="$(swift build -c release --arch arm64 --scratch-path "$ROOT/.build-arm64" --show-bin-path)/Matalogic"
X86_BIN="$(swift build -c release --arch x86_64 --scratch-path "$ROOT/.build-x86_64" --show-bin-path)/Matalogic"

APP="$ROOT/dist/Matalogic.app"
mkdir -p "$APP/Contents/MacOS"

lipo -create "$ARM_BIN" "$X86_BIN" -output "$APP/Contents/MacOS/Matalogic"
chmod +x "$APP/Contents/MacOS/Matalogic"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>de</string>
    <key>CFBundleExecutable</key>
    <string>Matalogic</string>
    <key>CFBundleIdentifier</key>
    <string>app.matalogic.Matalogic</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Matalogic</string>
    <key>CFBundleDisplayName</key>
    <string>Matalogic</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.4</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Matalogic erkennt Lyrics aus einer von dir ausgewählten Vocal-Spur.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc signing keeps the bundle internally consistent for development builds.
codesign --force --deep --sign - "$APP"

lipo -archs "$APP/Contents/MacOS/Matalogic"

ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/Matalogic-universal.zip"

echo "Built: $ROOT/dist/Matalogic-universal.zip"
