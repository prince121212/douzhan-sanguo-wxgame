#!/bin/bash
# ============================================================================
# build_brotli.sh —— 实验性Brotli 构建
# ----------------------------------------------------------------------------
# 做法：复制基线产物 -> 压缩 wasm/pck/js 为 .br -> 注入解压加载层。
# 原产物 build_web/ 不被触碰，实验产物落在 build_brotli/。
# 每一步都产出可核对的体积对照表。
# ============================================================================
set -euo pipefail

# 脚本自身位置推导项目根，避免写死本机路径
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/_backup/BASELINE_20261016/build_web"
DST="$ROOT/build_brotli"
# brotli-wasm 解码器来源：可用 BRSRC 环境变量覆盖
BRSRC="${BRSRC:-$ROOT/node_modules/brotli-wasm/pkg.bundler}"
PY="${PYTHON:-python3}"

echo "=== [1/5] 复制基线产物 ==="
rm -rf "$DST"
mkdir -p "$DST"
cp "$SRC"/* "$DST"/
cd "$DST"
rm -f SHA256SUMS.txt
echo "  源: $SRC"
ls -la | tail -n +4 | awk '{printf "    %-32s %10.2f MB\n",$9,$5/1048576}'

echo
echo "=== [2/5] Brotli 压缩 ==="
# -q 11 最高压缩。--no-copy-stat 避免被压缩工具改写源文件权限/时间
for f in index.wasm index.pck index.js; do
  before=$(stat -f%z "$f")
  brotli -q 11 -f -k --no-copy-stat -o "$f.br" "$f"
  after=$(stat -f%z "$f.br")
  ratio=$("$PY" -c "print(f'{$before/$after:.2f}x')")
  printf "  %-14s %10.2f MB -> %8.2f MB  (%s)\n" "$f" \
    "$("$PY" -c "print($before/1048576)")" \
    "$("$PY" -c "print($after/1048576)")" "$ratio"
done

# 解码器 wasm 也压缩
echo "  --- brotli 解码器 ---"
cp "$BRSRC/brotli_wasm_bg.wasm" ./brotli_dec.wasm
brotli -q 11 -f -k --no-copy-stat -o ./brotli_dec.wasm.br ./brotli_dec.wasm
printf "  %-14s %10.2f MB -> %8.2f MB\n" "brotli_dec.wasm" \
  "$("$PY" -c "print($(stat -f%z brotli_dec.wasm)/1048576)")" \
  "$("$PY" -c "print($(stat -f%z brotli_dec.wasm.br)/1048576)")"

# 复制解码器的 JS 胶水（brotli_wasm_bg.js 只 12KB，是 wasm 导出的绑定代码）
cp "$BRSRC/brotli_wasm_bg.js" ./brotli_dec.js
cp "$BRSRC/brotli_wasm.js"  ./brotli_dec_entry.js
echo "  解码器 JS 胶水已复制"

echo
echo "=== [3/5] 体积对照表 ==="
"$PY" - "$DST" <<'PY'
import os,sys
d=sys.argv[1]
def sz(p):
    return os.path.getsize(os.path.join(d,p)) if os.path.exists(os.path.join(d,p)) else 0
# 上传实际会用到的：.br 替代原文件（微信按文件体积计费）
keep=["index.html","index.js","index.png","index.icon.png","index.apple-touch-icon.png",
      "index.audio.worklet.js","index.audio.position.worklet.js",
      "index.wasm.br","index.pck.br","brotli_dec.wasm.br","brotli_dec.js","brotli_dec_entry.js"]
tot=sum(sz(f) for f in keep)
orig=39_514_754+10_885_528+279_815+5_445+21_443+12_888+26_002+7_298+2_973
print(f"  基线(未压缩)     : {orig/1048576:8.2f} MB")
print(f"  Brotli 后总占用  : {tot/1048576:8.2f} MB")
print(f"  净节省           : {(orig-tot)/1048576:8.2f} MB   ({(orig-tot)/orig*100:.1f}%)")
print()
print("  逐项：")
for f in keep:
    if sz(f): print(f"    {f:<34}{sz(f)/1048576:8.3f} MB")
PY

echo
echo "=== [4/5] 校验 .br 可正确还原 ==="
for f in index.wasm index.pck index.js; do
  if brotli -d -f -k -o "/tmp/_verify_$f" "$f.br" 2>/dev/null; then
    a=$(shasum -a 256 "$f" | awk '{print $1}')
    b=$(shasum -a 256 "/tmp/_verify_$f" | awk '{print $1}')
    if [ "$a" = "$b" ]; then echo "  ✅ $f 解压后与原文件字节一致"
    else echo "  ❌ $f 校验和不匹配!"; exit 1; fi
    rm -f "/tmp/_verify_$f"
  else
    echo "  ❌ $f 解压失败"; exit 1
  fi
done

echo
echo "=== [5/5] 交付 ==="
echo "  实验产物: $DST"
echo "  原产物  : $ROOT/build_web  （未改动）"
echo "  下一步  : 注入 br 加载层并跑对比验证"