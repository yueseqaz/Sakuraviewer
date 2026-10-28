#!/bin/bash
# Sakuraviewer 命令行编译脚本（无需 Xcode GUI，仅 Command Line Tools 即可）
# 用法: ./scripts/build.sh [debug|release]   默认 debug
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
case "$CONFIG" in
  debug|release) ;;
  *) echo "用法: $0 [debug|release]"; exit 1 ;;
esac

# 无 Xcode（仅 Command Line Tools）时，macOS 26+ SDK 的 SwiftUI 把 @State 等实现为
# 外部宏，其插件（libSwiftUIMacros.dylib）只随完整 Xcode 提供。
# 解决方案：改用 CLT 自带的 macOS 15.2 SDK 编译（API 向下兼容 macOS 13 目标）。
if xcode-select -p 2>/dev/null | grep -q "CommandLineTools"; then
  for sdk in MacOSX15.5.sdk MacOSX15.4.sdk MacOSX15.3.sdk MacOSX15.2.sdk MacOSX15.1.sdk MacOSX15.0.sdk; do
    if [[ -d "/Library/Developer/CommandLineTools/SDKs/$sdk" ]]; then
      export SDKROOT="/Library/Developer/CommandLineTools/SDKs/$sdk"
      echo "==> 检测到仅 CLT 环境，使用 $sdk 编译（规避 SwiftUI 宏插件缺失）"
      break
    fi
  done
fi

echo "==> swift build -c $CONFIG --product SakuraViewer"
swift build -c "$CONFIG" --product SakuraViewer

BIN_PATH="$(swift build -c "$CONFIG" --product SakuraViewer --show-bin-path)"
echo "==> 编译完成"
echo "    可执行文件: $BIN_PATH/SakuraViewer"
