#!/bin/bash
# 生成可双击运行的 .app（Release 构建 + ad-hoc 签名 + zip）
# 用法: ./scripts/package.sh
#   环境变量 APP_NAME 可自定义包名，例如 APP_NAME=OmniViewer ./scripts/package.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="${APP_NAME:-SakuraViewer}"
DISPLAY_NAME="Sakura-Viewer"
OUT="dist"

./scripts/make_app.sh release "$OUT/$APP_NAME.app" "$DISPLAY_NAME"

echo "==> 打包 zip（便于分发 / CI artifact）"
cd "$OUT"
rm -f "$APP_NAME-macOS.zip"
zip -qry "$APP_NAME-macOS.zip" "$APP_NAME.app"
cd ..

echo "==> 产物:"
ls -lh "$OUT/$APP_NAME.app/Contents/MacOS/$APP_NAME" "$OUT/$APP_NAME-macOS.zip"
echo "    双击 $OUT/$APP_NAME.app 即可运行；zip 为分发用压缩包。"
