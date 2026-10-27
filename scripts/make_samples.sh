#!/bin/bash
# 生成 Samples/ 目录的样例文件（图片/视频/音频/PDF/代码/TXT/Markdown）
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> 生成样例文件"
swift scripts/make_samples.swift Samples
ls -lh Samples/
