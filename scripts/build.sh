#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/version.py >/dev/null
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-cache" swift build --build-system native --disable-sandbox --cache-path .build/spm-cache -c release
bin_dir="$(CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" swift build --build-system native --disable-sandbox --cache-path .build/spm-cache -c release --show-bin-path)"
app="$(pwd)/build/ClothesDock.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/ClothesDock" "$app/Contents/MacOS/ClothesDock"
cp scripts/dock-watchdog.sh "$app/Contents/Resources/dock-watchdog.sh"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
python3 scripts/version.py --write-plist "$app/Contents/Info.plist" >/dev/null
xattr -cr "$app"
codesign --force --sign - --identifier local.clothesdock "$app"
printf '%s\n' "$app"
