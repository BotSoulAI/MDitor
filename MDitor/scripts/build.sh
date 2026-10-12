#!/bin/bash
# MDitor 一键构建脚本：编译 → 生成图标 → 组装 .app → ad-hoc 签名 → 跑单元测试
# 用法：bash scripts/build.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PARENT="$(dirname "$ROOT")"
APP="$PARENT/MDitor.app"
cd "$ROOT"

echo "[1/5] 编译应用二进制（swiftc -O 发行模式）..."
mkdir -p .build/release
swiftc -swift-version 5 -O -parse-as-library \
  Sources/MDitorCore/*.swift Sources/MDitor/*.swift \
  -o .build/release/MDitor \
  -framework AppKit -framework SwiftUI -framework UniformTypeIdentifiers

echo "[2/5] 生成应用图标..."
mkdir -p resources/AppIcon.iconset .build
swiftc -swift-version 5 scripts/make_icon.swift -o .build/make_icon
.build/make_icon resources/icon.png
sips -z 16 16 resources/icon.png --out resources/AppIcon.iconset/icon_16x16.png >/dev/null
sips -z 32 32 resources/icon.png --out resources/AppIcon.iconset/icon_16x16@2x.png >/dev/null
sips -z 32 32 resources/icon.png --out resources/AppIcon.iconset/icon_32x32.png >/dev/null
sips -z 64 64 resources/icon.png --out resources/AppIcon.iconset/icon_32x32@2x.png >/dev/null
sips -z 128 128 resources/icon.png --out resources/AppIcon.iconset/icon_128x128.png >/dev/null
sips -z 256 256 resources/icon.png --out resources/AppIcon.iconset/icon_128x128@2x.png >/dev/null
sips -z 256 256 resources/icon.png --out resources/AppIcon.iconset/icon_256x256.png >/dev/null
sips -z 512 512 resources/icon.png --out resources/AppIcon.iconset/icon_256x256@2x.png >/dev/null
sips -z 512 512 resources/icon.png --out resources/AppIcon.iconset/icon_512x512.png >/dev/null
sips -z 1024 1024 resources/icon.png --out resources/AppIcon.iconset/icon_512x512@2x.png >/dev/null
iconutil -c icns resources/AppIcon.iconset -o resources/AppIcon.icns

echo "[3/5] 组装 .app 包..."
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MDitor "$APP/Contents/MacOS/MDitor"
cp resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp scripts/Info.plist "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/MDitor"

echo "[4/5] 代码签名（ad-hoc）..."
codesign --force --sign - "$APP"

echo "[5/5] 运行解析器单元测试..."
swiftc -swift-version 5 Sources/MDitorCore/*.swift Tests/MDitorCoreTests/main.swift -o .build/tests
.build/tests

echo ""
echo "构建完成：$APP"
