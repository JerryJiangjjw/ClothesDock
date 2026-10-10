#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
version="$(python3 scripts/version.py)"
arch="$(uname -m)"
case "$arch" in arm64|x86_64) ;; *) printf 'Unsupported architecture: %s\n' "$arch" >&2; exit 1 ;; esac
if [ -n "${EXPECTED_ARCH:-}" ] && [ "$arch" != "$EXPECTED_ARCH" ]; then
    printf 'Runner architecture %s does not match %s\n' "$arch" "$EXPECTED_ARCH" >&2
    exit 1
fi
case "${1:-}" in
    '') ./scripts/build.sh ;;
    --skip-build) ;;
    *) printf 'Usage: %s [--skip-build]\n' "$0" >&2; exit 1 ;;
esac
app="$PWD/build/ClothesDock.app"
actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
[ "$actual_version" = "$version" ] || { printf 'Application version does not match VERSION\n' >&2; exit 1; }
lipo -verify_arch "$arch" "$app/Contents/MacOS/ClothesDock"
stage="$(mktemp -d "$PWD/build/dmg-stage.XXXXXX")"
trap 'rm -rf "$stage"' EXIT HUP INT TERM
ditto --norsrc --noextattr "$app" "$stage/ClothesDock.app"
codesign --verify --strict "$stage/ClothesDock.app"
ln -s /Applications "$stage/Applications"
cp LICENSE "$stage/LICENSE.txt"
cat > "$stage/README.txt" <<NOTES
ClothesDock $version ($arch)

将 ClothesDock.app 拖到 Applications 文件夹，再打开应用。
系统要求：macOS 14 或更高版本。
本版本采用 ad-hoc 签名，尚未进行 Apple 公证。
项目主页：https://github.com/JerryJiangjjw/ClothesDock
NOTES
name="ClothesDock-${version}-${arch}.dmg"
hdiutil create -volname "ClothesDock $version" -srcfolder "$stage" -format UDZO -ov "$PWD/build/$name"
hdiutil verify "$PWD/build/$name"
(cd build && shasum -a 256 "$name" > "$name.sha256")
printf '%s\n' "$PWD/build/$name"
