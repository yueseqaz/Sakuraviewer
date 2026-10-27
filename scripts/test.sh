#!/bin/bash
# Sakura-Viewer 测试脚本：运行零依赖测试执行器（本地与 CI 同一路径）
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> swift run SakuraViewerTests"
swift run SakuraViewerTests
