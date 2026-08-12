#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="$PROJECT_DIR/dist/Today.app"
CONTENTS_DIR="$APP_DIR/Contents"

cd "$PROJECT_DIR"
if [[ -z "${SDKROOT:-}" ]]; then
    if [[ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk" ]]; then
        export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
    else
        export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
    fi
fi
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/ModuleCache"
swift build -c release --triple arm64-apple-macosx13.0 --disable-sandbox
swift build -c release --triple x86_64-apple-macosx13.0 --disable-sandbox

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
lipo -create \
    "$PROJECT_DIR/.build/arm64-apple-macosx/release/TodayBar" \
    "$PROJECT_DIR/.build/x86_64-apple-macosx/release/TodayBar" \
    -output "$CONTENTS_DIR/MacOS/TodayBar"
cp "$PROJECT_DIR/AppBundle/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/AppBundle/Today.icns" "$CONTENTS_DIR/Resources/Today.icns"
chmod +x "$CONTENTS_DIR/MacOS/TodayBar"

codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
