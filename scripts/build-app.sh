#!/bin/bash
# 打包 AICreditBar.app（release 或 debug），就地生成于 ./build/AICreditBar.app
# 用法：
#   ./scripts/build-app.sh            # release
#   ./scripts/build-app.sh debug
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
CONFIG="${1:-release}"

IDENTITY="$ROOT/Sources/AICreditBar/App/AppIdentity.swift"
read_identity() {
  local key="$1"
  sed -n "s/^[[:space:]]*static let ${key} = \"\\([^\"]*\\)\".*/\\1/p" "$IDENTITY" | head -n 1
}

APP_NAME="$(read_identity name)"
APP_BUNDLE_ID="$(read_identity bundleIdentifier)"
APP_VERSION="$(read_identity version)"
if [ -z "$APP_NAME" ] || [ -z "$APP_BUNDLE_ID" ] || [ -z "$APP_VERSION" ]; then
  echo "错误：无法从 $IDENTITY 读取 AppIdentity.name / bundleIdentifier / version" >&2
  exit 1
fi

APP="$ROOT/build/$APP_NAME.app"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN="$ROOT/.build/$CONFIG/$APP_NAME"
if [ ! -x "$BIN" ]; then
  echo "错误：未找到编译产物 $BIN（Package.swift 的 target 名必须与 AppIdentity.name 一致）" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
ICON="$ROOT/Resources/AppIcon.icns"
if [ ! -f "$ICON" ]; then
  echo "错误：缺少应用图标 $ICON" >&2
  exit 1
fi
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $APP_BUNDLE_ID" "$APP/Contents/Info.plist"
if /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$APP/Contents/Info.plist"
else
  /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $APP_VERSION" "$APP/Contents/Info.plist"
fi

# SwiftPM 资源包（厂商 Logo 等），必须放进 .app 才能被 Bundle.module 找到
BIN_DIR="$(dirname "$BIN")"
shopt -s nullglob
for bundle in "$BIN_DIR"/*.bundle; do
  cp -R "$bundle" "$APP/Contents/Resources/"
done
shopt -u nullglob

# 本机运行需要（Apple Silicon）ad-hoc 签名
codesign --force --sign - "$APP"

# ditto 会保留包结构和签名；不要用 zip -r
ARCH="$(uname -m)"
ZIP_NAME="${APP_NAME}-${APP_VERSION:-dev}-macos-${ARCH}.zip"
ZIP="$ROOT/build/$ZIP_NAME"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo ""
echo "✔ 已生成：$APP"
echo "  压缩：$ZIP"
echo "  运行：open \"$APP\""
echo "  自测：$APP/Contents/MacOS/$APP_NAME --selftest"
