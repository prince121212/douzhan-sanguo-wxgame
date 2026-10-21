#!/usr/bin/env python3
"""
字体子集生成器 —— 让「代码里出现的每个字」都在字体文件里
============================================================================
为什么需要它：
  为了压体积，三个字体文件都是子集（各约 1000 个汉字）。但文案一直在加，
  新加的字（奖 / 佩 / 晋 / 望 / 评 / 价 …）不在子集里，就会渲染成豆腐块。

  桌面 Godot 上看不出来：allow_system_fallback 会去用 macOS 系统字体兜底。
  微信小游戏里 OS.get_system_fonts() 返回 0，SystemFont 也不认字 —— 没有兜底，
  直接乱码。所以只能把字补进字体文件。

做法：
  1. 扫描 godot/scripts/**/*.gd 的字符串字面量（跳过 # 注释、跳过 print/日志）
  2. 扫描 godot/config/**/*.json 的所有字符串值
  3. 加上 ASCII + 常用标点 + 全角空格
  4. 从「全量字体」里子集化出只含这些字的字体，覆盖 godot/assets/fonts/*.ttf
  5. 自检：逐字确认新字体都有，缺一个就报错退出

用法：
  python3 _tools/build_fonts.py            # 生成 + 自检
  python3 _tools/build_fonts.py --check    # 只检查当前字体够不够（不改文件）
============================================================================
"""
import argparse
import glob
import json
import os
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
GODOT = ROOT / "godot"
FONT_DIR = GODOT / "assets" / "fonts"

# 全量字体来源（体积大，不入库；只在生成子集时用）
FULL_SOURCES = {
    "NotoSansSC.ttf": ROOT.parent / "斗战三国" / "assets" / "fonts" / "NotoSansSC.ttf",
    "serif.ttf": ROOT.parent / "斗战三国" / "assets" / "fonts" / "serif.ttf",
    "brush.ttf": ROOT.parent / "斗战三国" / "assets" / "fonts" / "brush.ttf",
}

# 只出现在日志里、不会画到屏幕上的符号（字体里本来也没有，不用管）
LOG_ONLY = set("✅❌⚠️")

# 无论代码里有没有，都带上：完整 ASCII + 中文标点 + 全角空格
ALWAYS = "".join(chr(c) for c in range(0x20, 0x7F)) + "　、。，．：；！？（）「」『』《》…—·×÷｜"

LOG_CALLS = ("print(", "printerr(", "push_error(", "push_warning(", "print_rich(")


# ---------------------------------------------------------------- 字符采集

def strip_comments_and_logs(src: str) -> str:
    """去掉 # 注释；并把 print/push_error 之类整条语句丢掉（日志里的字不用渲染）。"""
    out = []
    i, n = 0, len(src)
    q = None
    triple = False
    while i < n:
        c = src[i]
        if q:
            if triple:
                if src.startswith(q * 3, i):
                    out.append(q * 3)
                    i += 3
                    q = None
                    triple = False
                    continue
            else:
                if c == "\\" and i + 1 < n:
                    out.append(src[i:i + 2])
                    i += 2
                    continue
                if c == q:
                    out.append(c)
                    i += 1
                    q = None
                    continue
            out.append(c)
            i += 1
            continue
        if c in ('"', "'"):
            if src.startswith(c * 3, i):
                q = c
                triple = True
                out.append(c * 3)
                i += 3
                continue
            q = c
            out.append(c)
            i += 1
            continue
        if c == "#":
            while i < n and src[i] != "\n":
                i += 1
            continue
        out.append(c)
        i += 1
    text = "".join(out)
    # 丢掉日志语句所在的整行
    kept = []
    for line in text.split("\n"):
        s = line.strip()
        if any(s.startswith(k) for k in LOG_CALLS):
            continue
        kept.append(line)
    return "\n".join(kept)


def string_literals(src: str):
    lits = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c in ('"', "'"):
            if src.startswith(c * 3, i):
                j = src.find(c * 3, i + 3)
                if j < 0:
                    break
                lits.append(src[i + 3:j])
                i = j + 3
                continue
            j = i + 1
            buf = []
            while j < n:
                if src[j] == "\\" and j + 1 < n:
                    buf.append(src[j:j + 2])
                    j += 2
                    continue
                if src[j] == c:
                    break
                buf.append(src[j])
                j += 1
            lits.append("".join(buf))
            i = j + 1
            continue
        i += 1
    return lits


def collect_chars() -> set:
    # 只收「字符串字面量」里的字符：注释里、日志里的中文不需要渲染。
    chars = set(ALWAYS)
    for p in sorted(glob.glob(str(GODOT / "scripts" / "**" / "*.gd"), recursive=True)):
        src = strip_comments_and_logs(Path(p).read_text(encoding="utf-8"))
        for lit in string_literals(src):
            chars |= {ch for ch in lit if ord(ch) > 0x7F}
    for p in sorted(glob.glob(str(GODOT / "config" / "**" / "*.json"), recursive=True)):
        data = json.loads(Path(p).read_text(encoding="utf-8"))

        def walk(v):
            if isinstance(v, str):
                chars.update(ch for ch in v if ord(ch) > 0x7F)
            elif isinstance(v, dict):
                for k, x in v.items():
                    walk(k)
                    walk(x)
            elif isinstance(v, list):
                for x in v:
                    walk(x)

        walk(data)
    return chars - LOG_ONLY


def cmap_of(path) -> set:
    f = TTFont(str(path), fontNumber=0)
    s = set()
    for t in f["cmap"].tables:
        s |= set(t.cmap.keys())
    return s


# ---------------------------------------------------------------- 生成

def build(chars: set) -> int:
    text = "".join(sorted(chars))
    failed = False
    for name, src in FULL_SOURCES.items():
        out = FONT_DIR / name
        if not src.exists():
            print(f"❌ 找不到全量字体 {src}（只在本地生成子集时需要，仓库里不存）")
            failed = True
            continue
        opts = subset.Options()
        opts.layout_features = ["*"]
        opts.name_IDs = ["*"]
        opts.notdef_outline = True
        opts.recalc_bounds = True
        opts.drop_tables += ["DSIG"]
        font = subset.load_font(str(src), opts)
        sub = subset.Subsetter(options=opts)
        sub.populate(text=text)
        sub.subset(font)
        tmp = str(out) + ".new"
        subset.save_font(font, tmp, opts)
        os.replace(tmp, out)

        cm = cmap_of(out)
        miss = [c for c in sorted(chars) if ord(c) not in cm]
        size = out.stat().st_size / 1024
        print(f"  {name}: {size:6.0f} KB  字符 {len(cm)}  缺 {len(miss)}")
        if miss:
            # 全量字体本身就没有这些字形（比如马善政缺 · ≥ →），只能靠 fallback 链
            src_cm = cmap_of(src)
            impossible = [c for c in miss if ord(c) not in src_cm]
            real_miss = [c for c in miss if ord(c) in src_cm]
            if real_miss:
                print("     ❌ 子集化后仍缺（源字体有，异常）：" + "".join(real_miss))
                failed = True
            if impossible:
                print("     ⚠️  源字体本身没有，靠 fallback：" + "".join(impossible))
    return 1 if failed else 0


def check(chars: set) -> int:
    """检查现有子集够不够。只有「源字体本来有、子集里却丢了」才算失败；
    源字体本身就没有的字形（书法字体缺 · → ≥ 之类）只警告，靠 fallbacks 兜。"""
    bad = 0
    for name, src in FULL_SOURCES.items():
        p = FONT_DIR / name
        cm = cmap_of(p)
        src_cm = cmap_of(src) if src.exists() else None
        miss = [c for c in sorted(chars) if ord(c) not in cm]
        if not miss:
            print(f"  {name}: ✅ 够用")
            continue
        if src_cm is None:
            print(f"  {name}: 缺 {len(miss)}（无全量字体可比对，视为失败）")
            bad += len(miss)
            continue
        impossible = [c for c in miss if ord(c) not in src_cm]
        real = [c for c in miss if ord(c) in src_cm]
        if real:
            print(f"  {name}: ❌ 缺 {len(real)} -> {''.join(real)}")
            bad += len(real)
        if impossible:
            print(f"  {name}: ⚠️  源字体无此字形（走 fallback）：{''.join(impossible)}")
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="只检查，不重新生成")
    args = ap.parse_args()

    chars = collect_chars()
    print(f"=== 字体字符集 ===\n  需要 {len(chars)} 个字符（含 ASCII 与标点）")
    if args.check:
        rc = check(chars)
        print("\n✅ 当前字体够用。" if rc == 0 else "\n❌ 字体缺字，请运行 python3 _tools/build_fonts.py")
        return rc
    print("=== 生成子集 ===")
    rc = build(chars)
    print("\n✅ 字体已更新。" if rc == 0 else "\n❌ 生成失败，见上面报错。")
    return rc


if __name__ == "__main__":
    sys.exit(main())
