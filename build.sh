#!/bin/bash
# 用法：
#   ./build.sh            构建通用二进制（Apple 芯片 + Intel）到 build/OneClear.app
#   ./build.sh --install  构建后安装到 /Applications 并启动
#
# 签名：设置 SIGN_IDENTITY 用指定证书签名（可写进不入库的 .signing.env）；
# 不设置则临时签名，能运行，但每次重新构建都要重新授予「辅助功能」权限。
# VERSION 用于写入版本号（Action 从 tag 传入）。
set -euo pipefail
cd "$(dirname "$0")"

IDENTITY_FROM_ENV="${SIGN_IDENTITY:-}"
[ -f .signing.env ] && source .signing.env
SIGN_IDENTITY="${IDENTITY_FROM_ENV:-${SIGN_IDENTITY:--}}"
APP=build/OneClear.app

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos14" -o "build/OneClear-$arch" Sources/*.swift
done
lipo -create -output "$APP/Contents/MacOS/OneClear" build/OneClear-arm64 build/OneClear-x86_64
rm build/OneClear-arm64 build/OneClear-x86_64

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns Resources/StatusIcon.svg "$APP/Contents/Resources/"
if [ -n "${VERSION:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
fi

if [ "$SIGN_IDENTITY" = "-" ]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
echo "已构建 $APP"

if [ "${1:-}" = "--install" ]; then
  pkill -x OneClear || true
  rm -rf /Applications/OneClear.app
  cp -R "$APP" /Applications/
  open /Applications/OneClear.app
  echo "已安装并启动 /Applications/OneClear.app"
fi
