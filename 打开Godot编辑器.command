#!/bin/bash
# 双击本文件：用 Godot 编辑器打开本项目的 godot/ 工程
# 打开后按 F10 可调出「数值控制台」，按 F5 运行游戏。

cd "$(dirname "$0")" || exit 1

GODOT="/Users/huangchangwei/tools/godot/Godot.app/Contents/MacOS/Godot"
PROJ="$(pwd)/godot"

if [ ! -x "$GODOT" ]; then
  echo "❌ 找不到 Godot：$GODOT"
  echo "   请修改本文件里的 GODOT 路径。"
  read -r -p "按回车关闭…"
  exit 1
fi

if [ ! -f "$PROJ/project.godot" ]; then
  echo "❌ 找不到工程：$PROJ/project.godot"
  read -r -p "按回车关闭…"
  exit 1
fi

echo "▶ 正在用 Godot 打开：$PROJ"
echo "  打开后：F5 运行游戏 · F10 数值控制台 · F9 热重载配置"
"$GODOT" --editor --path "$PROJ"
