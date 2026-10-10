#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-cache"
set -- --build-system native --disable-sandbox --cache-path .build/spm-cache --disable-xctest --enable-swift-testing
frameworks="$(xcode-select -p)/Library/Developer/Frameworks"
if [ -d "$frameworks/Testing.framework" ]; then
    set -- "$@" -Xswiftc "-F$frameworks" -Xlinker -rpath -Xlinker "$frameworks"
fi
swift test "$@"
python3 scripts/test-watchdog.py
