#!/bin/bash
# 组装 .app bundle（供 run.sh / package.sh 复用）
# 用法: make_app.sh <debug|release> <输出路径.app> [Bundle显示名]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:?用法: make_app.sh <debug|release> <输出路径.app> [显示名]}"
APP_PATH="${2:?缺少输出路径}"
DISPLAY_NAME="${3:-Sakuraviewer}"
APP_NAME="$(basename "$APP_PATH" .app)"
VERSION="0.1.0"

# 复用 build.sh 的 SDK 选择逻辑
if xcode-select -p 2>/dev/null | grep -q "CommandLineTools"; then
  for sdk in MacOSX15.5.sdk MacOSX15.4.sdk MacOSX15.3.sdk MacOSX15.2.sdk MacOSX15.1.sdk MacOSX15.0.sdk; do
    if [[ -d "/Library/Developer/CommandLineTools/SDKs/$sdk" ]]; then
      export SDKROOT="/Library/Developer/CommandLineTools/SDKs/$sdk"
      break
    fi
  done
fi

echo "==> swift build -c $CONFIG --product SakuraViewer"
swift build -c "$CONFIG" --product SakuraViewer
BIN="$(swift build -c "$CONFIG" --product SakuraViewer --show-bin-path)/SakuraViewer"

echo "==> 组装 $APP_PATH"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN" "$APP_PATH/Contents/MacOS/$APP_NAME"
chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"

if [[ ! -f "Packaging/AppIcon.icns" ]]; then
  echo "==> 图标缺失，先生成 AppIcon.icns"
  ./scripts/make_icon.sh
fi
cp Packaging/AppIcon.icns "$APP_PATH/Contents/Resources/AppIcon.icns"

printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh-Hans</string>
    <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>com.sakuraviewer.SakuraViewer</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Sakuraviewer Contributors. MIT License.</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>Image</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.image</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key><string>Video</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.movie</string>
                <string>public.mpeg-4</string>
                <string>com.apple.quicktime-movie</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key><string>Audio</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.audio</string>
                <string>public.mp3</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key><string>PDF</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>com.adobe.pdf</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key><string>Markdown</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key><string>Source Code</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.source-code</string>
                <string>public.json</string>
                <string>public.yaml</string>
                <string>public.xml</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key><string>Text</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.text</string>
                <string>public.plain-text</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

echo "==> Ad-hoc codesign"
codesign --force --sign - "$APP_PATH"

echo "==> 完成: $APP_PATH"
