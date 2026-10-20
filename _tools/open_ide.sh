#!/bin/bash
# ==========================================================================
# open_ide.sh —— 用【正确方式】在微信开发者工具打开斗战三国小游戏工程
# --------------------------------------------------------------------------
# 踩坑记录（2026-10-16 排查结论，改这个脚本前务必读完）：
#
#  1. 必须用 `cli open`，不要用 `cli open-other`！
#     - open-other 会把【父目录】斗战三国小游戏 打开成「纯文本编辑器」，
#       没有模拟器、没有编译、没有游戏 —— 看起来就像"打开有问题"。
#     - 父目录那条还会进 IDE 最近项目列表（plainTextEditProject: true），
#       之后从 IDE 界面点开会一直中招。看到它在列表里可以直接移除。
#
#  2. `cli open` 需要 project.config.json 里是【真实 AppID】。
#     空 appid / touristappid 会被服务端拒绝（报"不存在此 AppID"）。
#     当前借用 wx13f8272f953e806a（本机已登录账号下有权限）。
#
#  3. 端口固定 18575。若 IDE 已在其他端口启动，需先 quit IDE 再跑本脚本。
#
#  4. GUI 等价操作：IDE → 导入项目 → 目录选 .../斗战三国小游戏/wxgame
#     → AppID 选 wx13f8272f953e806a（不要选测试号/空）。
# ==========================================================================
set -e
CLI="/Applications/wechatwebdevtools.app/Contents/MacOS/cli"
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../wxgame" && pwd)"
PORT="18575"

if [ ! -f "$PROJ/game.js" ]; then
  echo "❌ 工程目录异常: $PROJ 下没有 game.js"
  exit 1
fi

echo "▶ 以游戏工程方式打开: $PROJ"
exec "$CLI" open --project "$PROJ" --port "$PORT"
