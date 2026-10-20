#!/bin/bash
# ============================================================================
# rollback.sh —— 一键回滚到指定阶段
# ----------------------------------------------------------------------------
# 用法：
#   bash _tools/rollback.sh            # 回到最初的基线（未优化）
#   bash _tools/rollback.sh step1      # 回到第一步 Brotli 优化后
#   bash _tools/rollback.sh list       # 列出所有可用阶段
#
# 原理：每个阶段都有一份完整快照在 _backup/ 下，回滚就是整目录还原。
# 还原后会立即校验 SHA256，确保恢复到位。
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP="$ROOT/_backup"

snapshot_path() {
  case "$1" in
    baseline) echo "$BACKUP/BASELINE_20261016/build_web" ;;
    step1)    echo "$BACKUP/STEP1_BROTLI_OK/build_brotli" ;;
    *)        echo "" ;;
  esac
}

case "${1:-baseline}" in
  list)
    echo "可用回滚点："
    for k in baseline step1; do
      d="$(snapshot_path "$k")"
      if [ -n "$d" ] && [ -d "$d" ]; then
        printf "  %-10s %-52s %s\n" "$k" "$(basename "$(dirname "$d")")" "$(du -sh "$d" | cut -f1)"
      fi
    done
    exit 0
    ;;
esac

KEY="${1:-baseline}"
SRC="$(snapshot_path "$KEY")"
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  echo "未知回滚点: $KEY"
  echo "可用: baseline | step1 | list"
  exit 1
fi

DEST="$ROOT/build_web"

echo "=== 回滚到: $KEY ==="
echo "源  : $SRC"
echo "目标: $DEST"

# 若当前目录是实验产物且名字不同，先归档而不是直接删，避免误删
if [ "$(basename "$DEST")" != "build_web" ]; then
  echo "未找到 build_web，跳过归档"
fi

# 保留现有 build_web 的一份拷贝（只做一次，防止覆盖最新成果）
if [ -d "$DEST" ] && [ ! -e "$BACKUP/_pre_rollback_$(date +%H%M%S)" ]; then
  ARC="$BACKUP/_pre_rollback_$(date +%H%M%S)"
  mkdir -p "$ARC"
  cp -R "$DEST/." "$ARC/"
  echo "已将当前 build_web 归档到: $ARC"
fi

mkdir -p "$DEST"
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

echo
echo "=== 校验 ==="
if [ -f "$DEST/SHA256SUMS.txt" ]; then
  (cd "$DEST" && shasum -a 256 -c SHA256SUMS.txt 2>&1 | tail -12)
else
  echo "(该阶段无 SHA256SUMS.txt，跳过校验)"
fi

echo
echo "=== 回滚完成 ==="
du -sh "$DEST"
echo
echo "注意：build_brotli/ 仍保留在原地，如需清理请手动确认后再删除。"