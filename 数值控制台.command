#!/bin/bash
# 双击本文件：启动数值控制台，自动在浏览器打开
# 改数值 → 保存 → 点「重新构建」→ 微信开发者工具自动刷新
cd "$(dirname "$0")" || exit 1
echo "▶ 启动数值控制台…（关掉这个窗口或按 Ctrl+C 即停止）"
exec python3 _tools/config_server.py
