#!/bin/bash
# ---------------------------------------------------------------------------
# 改代码后的快速复验：不重启微信开发者工具。
# 原理：IDE 会监听工程文件变化并自动重新编译，模拟器随之重启游戏、
#       重写启动日志（日志是全量重写，不是追加）。本脚本只是等新一轮
#       启动出现，然后把最新日志读给你看。
# 用法：bash _tools/recheck.sh [最长等待秒数，默认 45]
# 说明：
#   - 只改 game.js 等工程文件 → 用本脚本，几秒出结果；
#   - IDE 没开 / 冷启动 → 才需要 open_ide.sh 或 verify_ide.sh（会重启 IDE）。
# ---------------------------------------------------------------------------
WAIT=${1:-45}
LOG=$(ls -t "$HOME/Library/Application Support/微信开发者工具"/*/WeappSimulator/WeappFileSystem/*/*/usr/dzsg_boot.log 2>/dev/null | head -1)
if [ -z "$LOG" ]; then
  echo "❌ 找不到启动日志（IDE 可能没开）。请先: bash _tools/open_ide.sh"
  exit 1
fi

# 记录脚本启动时的“显示垫片”行数（每次游戏重新编译启动都会多一行）
BEFORE=$(grep -ac "显示垫片" "$LOG" 2>/dev/null); BEFORE=${BEFORE:-0}
echo "等待模拟器自动重新编译（当前第 $BEFORE 轮启动，最多等 ${WAIT}s）..."

DETECTED=0
for i in $(seq 1 "$WAIT"); do
  sleep 1
  NOW=$(grep -ac "显示垫片" "$LOG" 2>/dev/null); NOW=${NOW:-0}
  if [ "$NOW" -gt "$BEFORE" ]; then
    DETECTED=1
    echo "✅ 检测到新一轮启动（第 $NOW 轮），耗时约 ${i}s"
    break
  fi
done

if [ "$DETECTED" -eq 0 ]; then
  echo "⚠️ ${WAIT}s 内没有新启动。可能原因："
  echo "   1. 代码没变化（IDE 不重编）—— 属正常；"
  echo "   2. IDE 没开或模拟器没在跑 —— 用 verify_ide.sh 冷启动一次；"
  echo "   3. IDE 设置里关了文件监听自动编译。"
  exit 2
fi

sleep 3  # 让引擎把启动日志写完
echo "===== 最新启动日志（尾部 40 行）====="
tail -n 40 "$LOG"
echo "===== 关键判定 ====="
if grep -qa "引擎启动失败\|startGame reject" "$LOG"; then
  echo "❌ 启动失败，见上方日志"
  exit 1
fi
if grep -qa "显示垫片 innerWidth" "$LOG"; then
  echo "✅ 新一轮已用修复版 game.js 启动（显示垫片生效）"
else
  echo "⚠️ 新一轮没有「显示垫片」行——跑的可能不是预期版本"
fi
