#!/bin/zsh
# 在完整环境里编译所有脚本，打印报错
GODOT=/Users/huangchangwei/tools/godot/Godot.app/Contents/MacOS/Godot
cd "${0:A:h}/.."
$GODOT --headless --path . res://tools/check_scripts.tscn 2>&1 | grep -E "SCRIPT ERROR|ERROR|BAD|CHECKED|at: " | grep -vE "^\s*at: (GDScript|_ready|_collect)" | head -${1:-120}
