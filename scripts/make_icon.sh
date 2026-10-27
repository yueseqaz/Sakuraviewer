#!/bin/bash
# 生成应用图标：调用 Swift 绘制脚本输出 AppIcon.icns
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-Packaging/AppIcon.icns}"
echo "==> 生成图标 → $OUT"
swift scripts/make_icon.swift "$OUT"
