#!/usr/bin/env python3
"""从 CC0 刀光素材生成游戏用的白色贴图。

素材（CC0，可商用、可修改、无需署名）：
  Slash Effect Collection by Cethiel
    https://opengameart.org/content/slash-effect-collection
  Weapon Slash - Effect by Cethiel
    https://opengameart.org/content/weapon-slash-effect

为什么转成白色：原素材是灰白渐变，游戏里每个武将有自己的主题色，
白色 + modulate 才能让同一套刀光跟随武将换色，而不是每人一套图。

产出（godot/assets/fx/slash/）：
  arc_wide.png   大弧月牙  —— 横斩、回旋
  arc_thin.png   细长光刃  —— 突刺

用法：
  python3 _tools/build_fx_assets.py --src /path/to/slash_collection
"""
import argparse, os, sys
from PIL import Image, ImageChops

OUT = [
    ("arc_wide", "Big/Slash.png", 2),
    ("arc_thin", "Big/Slash Gradual.png", 2),
]


def to_white(im: Image.Image) -> Image.Image:
    """把「灰度笔触」转成「白色 + 亮度进 alpha」。

    关键：亮度必须写进 alpha，不能写进 RGB。
    写进 RGB 的话，贴图整体是不透明的，modulate 成绿色就变成一块实心绿饼；
    写进 alpha 才能保留笔触的浓淡，染色后是带渐变的光刃。
    """
    im = im.convert("RGBA")
    lum = im.convert("RGB").convert("L")
    a = im.getchannel("A")
    # 两者相乘：既保留原图的柔边，又保留笔触的明暗
    alpha = ImageChops.multiply(lum, a)
    white = Image.new("L", im.size, 255)
    return Image.merge("RGBA", (white, white, white, alpha))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--outdir", default="godot/assets/fx/slash")
    args = ap.parse_args()

    os.makedirs(args.outdir, exist_ok=True)
    for name, rel, up in OUT:
        p = os.path.join(args.src, rel)
        if not os.path.exists(p):
            raise SystemExit(f"!! 找不到 {p}")
        im = to_white(Image.open(p))
        bb = im.getbbox()
        im = im.crop((bb[0] - 4, bb[1] - 4, bb[2] + 4, bb[3] + 4))
        im = im.resize((im.width * up, im.height * up), Image.LANCZOS)
        dst = os.path.join(args.outdir, name + ".png")
        im.save(dst, optimize=True)
        print(f"  {name:<9} {im.width}x{im.height}  {os.path.getsize(dst)/1024:.0f} KB  <- {rel}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
