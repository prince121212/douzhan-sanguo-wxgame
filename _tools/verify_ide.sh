#!/bin/bash
# ==========================================================================
# verify_ide.sh —— 端到端复验：编译 + 模拟器实跑 + 读启动日志
# --------------------------------------------------------------------------
# 为什么需要它：
#   1. `cli open` 成功只代表 IDE 加载了目录，不代表游戏能跑；
#   2. `cli auto-preview` 走服务端编译+包体校验，能过说明工程侧健康；
#   3. 但"游戏真的跑起来吗"只有模拟器知道——game.js 会把全过程写进
#      <USER_DATA_PATH>/dzsg_boot.log，本脚本启动模拟器后直接读它。
#
# 判定标准（日志里按顺序出现）：
#   Godot Engine v4.7.x            -> 引擎 main() 已执行
#   OpenGL ES 3.0 (WebGL 2.0 ...)  -> GL 上下文创建成功
#   ✅ 引擎启动完成，游戏运行中     -> startGame promise resolve
#   帧率: XX fps                   -> 主循环持续渲染（活性的铁证）
#   像素采样#: RGBA=非黑, 画布=非0x0 -> 真实渲染内容（黑屏鉴别，2026-10-16 补）
#     教训：曾经"日志全绿、帧率48"但画面全黑——canvasResizePolicy=2 走
#     window.innerWidth（小游戏没有）-> NaN -> canvas 0x0，rAF 照样跳。
#     所以必须看到像素采样非黑 + 画布尺寸非 0 才算真跑起来。
#
# 已知非致命噪音：
#   WARNING: All audio drivers failed, falling back to the dummy driver.
#   -> 微信没有 AudioWorklet，Godot 4 web 音频走不了，优雅降级为静音。
#
# 用法：bash verify_ide.sh [等待秒数，默认50]
# ==========================================================================
set -e
CLI="/Applications/wechatwebdevtools.app/Contents/MacOS/cli"
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../wxgame" && pwd)"
PORT="18575"
WAIT="${1:-50}"   # 第一个参数可覆盖等待秒数，默认 50s

echo "▶ 1/3 重启工程窗口并拉起模拟器"
"$CLI" close --project "$PROJ" --port "$PORT" >/dev/null 2>&1 || true
sleep 2
"$CLI" open --project "$PROJ" --port "$PORT" >/dev/null
sleep 5
"$CLI" auto --project "$PROJ" --port "$PORT" >/dev/null
echo "   ✔ 已触发编译+预览（手机扫二维码可同测）"

echo "▶ 2/3 等待 ${WAIT}s 让引擎启动并渲染若干帧"
sleep "$WAIT"

echo "▶ 3/3 读取模拟器启动日志"
# 注意：路径含空格，必须用 glob（不能用 xargs ls，会被空格拆散）
LOG=$(ls -t "$HOME/Library/Application Support/微信开发者工具"/*/WeappSimulator/WeappFileSystem/*/*/usr/dzsg_boot.log 2>/dev/null | head -1)
if [ -z "$LOG" ]; then
  echo "   ❌ 找不到 dzsg_boot.log（模拟器没跑起来？）"
  exit 1
fi
echo "   日志: $LOG"
echo "   --------------------------------------------"
# 注意：必须用 -E（ERE）。本机 grep 的 BRE 不支持 \| 交替语法。
grep -aE "Godot Engine|OpenGL|audio driver|引擎启动完成|引擎启动失败|启动流程失败|帧率|像素采样|ERROR" "$LOG" | tail -25
echo "   --------------------------------------------"
if grep -qa "引擎启动完成" "$LOG"; then
  echo "   ✔ 引擎启动完成"
else
  echo "   ❌ 未通过：日志中没有『引擎启动完成』"
  exit 1
fi
# 黑屏鉴别：必须有像素采样，且画布非 0x0（黑屏根因见文件头注释）
if grep -qa "像素采样" "$LOG"; then
  LASTPX=$(grep -a "像素采样" "$LOG" | tail -1)
  echo "   $LASTPX"
  if echo "$LASTPX" | grep -qaE "画布=0x0|画布=0 x 0"; then
    echo "   ❌ 未通过：画布被压成 0x0（innerWidth/innerHeight 垫片失效？）"
    exit 1
  fi
  if echo "$LASTPX" | grep -qaE "RGBA=(0,0,0|0,0,0,|.*,0,0,0,255)"; then
    echo "   ⚠️ 中心像素全黑：画布有尺寸但内容可能是黑的，请人工截屏确认"
    exit 1
  fi
  echo "   ✅ 通过：引擎完整启动，且确认真实渲染内容（非 0x0 画布、非黑屏）"
else
  echo "   ⚠️ 日志中没有像素采样行（game.js 版本过旧？），仅日志级通过，建议人工确认画面"
fi
