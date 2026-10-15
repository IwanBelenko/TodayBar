#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"
if [[ -z "${SDKROOT:-}" ]]; then
    if [[ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]]; then
        export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
    else
        export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
    fi
fi
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/ModuleCache"

# Standalone Command Line Tools include Swift Testing but need an explicit framework path.
TODAY_DEVELOPER_PATH="$(xcode-select -p)"
TODAY_FRAMEWORKS="$TODAY_DEVELOPER_PATH/Library/Developer/Frameworks"
TODAY_SWIFT_BIN="$(dirname "$(xcrun --find swiftc)")"
test_flags=()
if [[ "$(swift test --help)" == *"--disable-xctest"* ]]; then
    test_flags+=(--disable-xctest)
fi
if [[ -d "$TODAY_FRAMEWORKS/Testing.framework" ]]; then
    test_flags+=(-Xswiftc -F -Xswiftc "$TODAY_FRAMEWORKS")
    test_flags+=(-Xswiftc -plugin-path -Xswiftc "$TODAY_SWIFT_BIN/../lib/swift/host/plugins/testing")
    test_flags+=(-Xlinker -rpath -Xlinker "$TODAY_FRAMEWORKS")
fi

swift test --build-system native --disable-sandbox \
    --cache-path "$PROJECT_DIR/.build/cache" \
    --config-path "$PROJECT_DIR/.build/config" \
    --security-path "$PROJECT_DIR/.build/security" \
    "${test_flags[@]}" "$@"
