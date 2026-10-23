#!/usr/bin/env python3
"""生成命中星芒用的两张贴图。

1. star4.png   —— 四芒星（|x|^p + |y|^p = 1，p<1 得到四角内凹的星形）
2. glow_soft.png —— 径向渐变柔光（alpha = (1-r)^3.4）

为什么不在运行时用 Image.create 逐像素算：
  192×192 × 4 次超采样 = 约 15 万次 pow()，第一次命中会卡一帧。
  预生成成 PNG 后，运行时只是一次纹理上传。

体积很小（各 < 20KB），可重复生成：
    python3 _tools/build_fx_star.py
"""
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "fx")

STAR_SIZE = 192
# p < 1：四角更长、边向内凹。0.62 接近参考视频里那种「细长四芒」
STAR_P = 0.62
SUPERSAMPLE = 2

GLOW_SIZE = 128
GLOW_POW = 1.7


def smoothstep(a: float, b: float, x: float) -> float:
    if a == b:
        return 0.0 if x < a else 1.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def build_star() -> None:
    """四芒星：四条细长针状尖刺 + 一个小核心。

    为什么不用 |x|^p+|y|^p=1 的超椭圆星：
      那个形状的尖角根部很粗、尖端很快收圆，缩到游戏分辨率后
      看起来像一块圆角菱形贴纸，没有「光刺」的锐利感。
      参考视频里的星芒是四根针——根部也细，越往外越尖。
    """
    n = STAR_SIZE
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    px = img.load()
    c = (n - 1) * 0.5
    inv = 1.0 / c
    step = 1.0 / SUPERSAMPLE
    # 每根针：(轴向, 长度, 根部半宽)
    # 横向比纵向长一点：斩击/突刺的接触面通常是横向的
    spikes = [
        (1.0, 0.0, 1.00, 0.105),
        (-1.0, 0.0, 1.00, 0.105),
        (0.0, 1.0, 0.80, 0.095),
        (0.0, -1.0, 0.80, 0.095),
    ]
    for y in range(n):
        for x in range(n):
            acc = 0.0
            for sy in range(SUPERSAMPLE):
                for sx in range(SUPERSAMPLE):
                    nx = (x + (sx + 0.5) * step - c) * inv
                    ny = (y + (sy + 0.5) * step - c) * inv
                    a = 0.0
                    for dx, dy, ln, hw in spikes:
                        if dx != 0.0:
                            t = nx * dx
                            perp = abs(ny)
                        else:
                            t = ny * dy
                            perp = abs(nx)
                        if t <= 0.0 or t >= ln:
                            continue
                        u = t / ln
                        # 针的轮廓：根部 hw，尖端收到 0。指数 >1 让尖更细
                        w = hw * (1.0 - u) ** 1.20
                        if perp >= w:
                            continue
                        # 横向 1px 的软边（相对宽度），纵向沿针自然淡出
                        edge = 1.0 - smoothstep(w * 0.72, w, perp)
                        fade = 1.0 - smoothstep(0.70, 1.0, u) * 0.85
                        a = max(a, edge * fade)
                    # 中心小核心：把四根针连起来，不要留一个空十字
                    r = (nx * nx + ny * ny) ** 0.5
                    if r < 0.20:
                        a = max(a, 1.0 - smoothstep(0.05, 0.20, r) * 0.60)
                    acc += a
            a = acc / (SUPERSAMPLE * SUPERSAMPLE)
            if a > 0.002:
                px[x, y] = (255, 255, 255, int(round(min(1.0, a) * 255)))
    path = os.path.join(OUT, "star4.png")
    img.save(path)
    print("wrote", path, os.path.getsize(path), "bytes")


def build_glow() -> None:
    n = GLOW_SIZE
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    px = img.load()
    c = (n - 1) * 0.5
    inv = 1.0 / c
    for y in range(n):
        for x in range(n):
            dx = (x - c) * inv
            dy = (y - c) * inv
            r = (dx * dx + dy * dy) ** 0.5
            if r < 1.0:
                a = (1.0 - r) ** GLOW_POW
                px[x, y] = (255, 255, 255, int(round(min(1.0, a) * 255)))
    path = os.path.join(OUT, "glow_soft.png")
    img.save(path)
    print("wrote", path, os.path.getsize(path), "bytes")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    build_star()
    build_glow()
