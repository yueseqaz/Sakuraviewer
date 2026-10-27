#!/bin/bash
# 构建并启动 Sakura-Viewer（Debug 构建，最快路径）
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/make_app.sh debug dist/SakuraViewer.app
echo "==> 启动 SakuraViewer.app"
open dist/SakuraViewer.app
