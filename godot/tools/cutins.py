#!/usr/bin/env python3
"""大招立绘：抠洋红底，缩放到 1280 宽，输出 assets/cutin/<武将>.png。
用法：python3 cutins.py <源目录> <输出目录>
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from slice_sheets import key_magenta  # noqa: E402


def main(src, out):
    os.makedirs(out, exist_ok=True)
    for f in sorted(os.listdir(src)):
        if not f.endswith("_cutin.png"):
            continue
        key = f[: -len("_cutin.png")]
        im = np.array(Image.open(os.path.join(src, f)).convert("RGBA"))
        rgb, alpha = key_magenta(im)
        # 去掉零碎的小斑点
        solid = alpha > 0.4
        lab, n = ndimage.label(solid)
        if n > 0:
            sizes = ndimage.sum(solid, lab, range(1, n + 1))
            keep = np.isin(lab, np.nonzero(sizes >= 40)[0] + 1)
            alpha = alpha * ndimage.binary_dilation(keep, iterations=2)
        outa = np.zeros_like(im)
        outa[..., :3] = rgb[..., :3].astype(np.uint8)
        outa[..., 3] = (alpha * 255).astype(np.uint8)
        img = Image.fromarray(outa)
        w = 1280
        h = int(img.height * w / img.width)
        img = img.resize((w, h), Image.LANCZOS)
        img.save(os.path.join(out, key + ".png"), optimize=True)
        print("[ok]", key, img.size)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
