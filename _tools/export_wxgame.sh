#!/bin/bash
# ============================================================================
# export_wxgame.sh —— 从 Godot 源码重新导出微信小游戏资源包
# ----------------------------------------------------------------------------
# 做了什么：
#   1. Godot 导出 Web 版到 build_web/
#   2. 把 index.pck 用 brotli -q 11 压成 index.pck.br
#   3. 替换 wxgame/pkg_assets/index.pck.br（旧的先备份到 _backup/）
#   4. 校验解压后与原 pck 字节一致，并同步 game.js 里的 fileSizes
#
# 说明：
#   · pkg_engine/index.js 与 index.wasm.br 是引擎本体，只有升级 Godot 版本时
#     才需要替换；日常改玩法只更新资源包（本脚本就是干这个）。
#   · game.js 是我们自己维护的宿主适配层，导出不会覆盖它。
#
# 用法：bash _tools/export_wxgame.sh
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/Users/huangchangwei/tools/godot/Godot.app/Contents/MacOS/Godot}"
BUILD="$ROOT/build_web"
WX="$ROOT/wxgame"

if [ ! -x "$GODOT" ]; then
  echo "❌ 找不到 Godot: $GODOT"
  echo "   可用 GODOT=/path/to/Godot 覆盖"
  exit 1
fi
command -v brotli >/dev/null || { echo "❌ 缺少 brotli（brew install brotli）"; exit 1; }

echo "▶ 1/4 导出 Web 版"
mkdir -p "$BUILD"
(cd "$ROOT/godot" && "$GODOT" --headless --path . --export-release "Web" "$BUILD/index.html" 2>&1 | tail -3)

echo "▶ 2/4 Brotli 压缩资源包"
(cd "$BUILD" && brotli -q 11 -f --no-copy-stat -o index.pck.br.new index.pck)
PCK_SIZE=$(stat -f%z "$BUILD/index.pck")
BR_SIZE=$(stat -f%z "$BUILD/index.pck.br.new")
printf "   index.pck %d bytes -> index.pck.br %d bytes (%.2f MB)\n" "$PCK_SIZE" "$BR_SIZE" \
  "$(python3 -c "print($BR_SIZE/1048576)")"

echo "▶ 3/4 替换 wxgame 资源包（旧包备份到 _backup/）"
mkdir -p "$ROOT/_backup"
if [ -f "$WX/pkg_assets/index.pck.br" ]; then
  cp "$WX/pkg_assets/index.pck.br" "$ROOT/_backup/index.pck.br.bak.$(date +%Y%m%d-%H%M%S)"
  # 只留最近 3 份，避免每次导出都堆 10MB
  ls -t "$ROOT/_backup"/index.pck.br.bak.* 2>/dev/null | tail -n +4 | while read -r old; do
    mkdir -p "$HOME/.Trash/dzsg_old_backups" && mv "$old" "$HOME/.Trash/dzsg_old_backups/"
  done
fi
cp "$BUILD/index.pck.br.new" "$WX/pkg_assets/index.pck.br"

echo "▶ 4/4 校验 & 同步 fileSizes"
A=$(brotli -d -c "$WX/pkg_assets/index.pck.br" | shasum -a 256 | awk '{print $1}')
B=$(shasum -a 256 "$BUILD/index.pck" | awk '{print $1}')
if [ "$A" != "$B" ]; then
  echo "❌ 解压后校验和不一致：$A != $B"
  exit 1
fi
echo "   ✅ 解压后与原 pck 字节一致"
python3 - "$WX/game.js" "$PCK_SIZE" <<'PY'
import re, sys
path, size = sys.argv[1], sys.argv[2]
s = open(path, encoding='utf-8').read()
s2, n = re.subn(r"('index\.pck': )\d+", r"\g<1>" + size, s)
if n:
    open(path, 'w', encoding='utf-8').write(s2)
    print("   已同步 game.js fileSizes.index.pck =", size)
PY

echo
echo "✅ 完成。现在在微信开发者工具里点「编译」即可看到新版本。"
