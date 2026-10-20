#!/usr/bin/env python3
"""程序化生成《斗战三国》UI 素材（暗金 / 朱红 / 水墨，像素风）并准备字体。

像素风做法：先在低分辨率“像素格”上画（1 像素格 = 2~4 屏幕像素），
渐变一律分级 + Bayer 抖动，最后最近邻放大，保证边缘是硬像素。
粒子类（dust / ring / vignette）需要平滑 alpha，直接按目标分辨率生成。

输出：assets/ui/*.png、assets/fonts/{NotoSansSC.ttf,title.ttf,CREDITS.md,NotoSansSC-OFL.txt}
用法：python3 tools/build_ui.py
"""
import glob
import os
import shutil

import numpy as np
from fontTools.ttLib import TTCollection
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WS = os.path.dirname(ROOT)
UI = os.path.join(ROOT, "assets", "ui")
FONTS = os.path.join(ROOT, "assets", "fonts")
NOTO_SRC = os.path.join(WS, "打包-斗将三国", "assets", "fonts", "NotoSansSC.ttf")
OFL_SRC = os.path.join(WS, "还原工程-windows", "licenses", "NotoSansSC-OFL.txt")
# 书法感粗体候选（按优先级）：楷体 Black > 华文行楷 Bold > 魏碑 > 宋体 Black
TITLE_CANDIDATES = [
    ("/System/Library/AssetsV2/com_apple_MobileAsset_Font8/*/AssetData/Kaiti.ttc", "Kaiti SC Black"),
    ("/System/Library/AssetsV2/com_apple_MobileAsset_Font8/*/AssetData/Xingkai.ttc", "Xingkai SC Bold"),
    ("/System/Library/AssetsV2/com_apple_MobileAsset_Font8/*/AssetData/WeibeiSC-Bold.otf", "Weibei SC Bold"),
    ("/System/Library/Fonts/Supplemental/Songti.ttc", "Songti SC Black"),
]

# ---- 调色板 -----------------------------------------------------------------
INK = (12, 8, 7)
INK2 = (30, 22, 19)
GOLD_HI = (238, 204, 118)
GOLD = (176, 132, 56)
GOLD_LO = (122, 86, 34)
GOLD_SH = (82, 56, 22)
VERMILION = (190, 38, 28)
ORANGE = (246, 142, 44)
PURPLE = (84, 32, 118)
BLUE = (50, 112, 232)

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], float) / 16.0 + 1 / 32


def bayer(h, w):
    return np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]


def lerp(a, b, t):
    a, b = np.asarray(a, float), np.asarray(b, float)
    t = np.asarray(t, float)[..., None] if np.ndim(t) else t
    return a + (b - a) * t


def quantize_t(t, levels):
    """把 0..1 的渐变参数量化成 levels 级，并用 Bayer 抖动过渡（像素风渐变）。"""
    h, w = t.shape
    q = np.floor(t * (levels - 1) + bayer(h, w))
    return np.clip(q / (levels - 1), 0, 1)


def to_img(rgb, alpha=None):
    rgb = np.clip(np.round(rgb), 0, 255).astype(np.uint8)
    if alpha is None:
        alpha = np.full(rgb.shape[:2], 255, np.uint8)
    else:
        alpha = np.clip(np.round(alpha * 255 if alpha.dtype != np.uint8 else alpha), 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, alpha]))


def up(img, s):
    return img.resize((img.width * s, img.height * s), Image.NEAREST)


def chamfer_mask(w, h, inset=0, cut=2):
    """斜切角矩形掩码（像素格坐标）。"""
    m = np.zeros((h, w), bool)
    for y in range(inset, h - inset):
        c = max(0, cut - (y - inset), cut - (h - 1 - inset - y))
        x0, x1 = inset + c, w - inset - c
        if x1 > x0:
            m[y, x0:x1] = True
    return m


# ---- 血条 / 体力条 / 大招条 ----------------------------------------------------
BAR_W, BAR_H, BAR_S = 256, 14, 2      # 像素格尺寸，放大 2 倍 = 512x28
TROUGH_INSET = 3                      # 上下金框厚度（像素格）
END_CAP = 8                           # 左右端盖宽度（像素格），槽 = [END_CAP, BAR_W-END_CAP)


def trough_mask():
    m = np.zeros((BAR_H, BAR_W), bool)
    m[TROUGH_INSET:BAR_H - TROUGH_INSET, END_CAP:BAR_W - END_CAP] = True
    return m


def bar_bg():
    w, h = BAR_W, BAR_H
    rgb = np.zeros((h, w, 3))
    a = np.zeros((h, w))
    outer = chamfer_mask(w, h, 0, 3)
    ring1 = chamfer_mask(w, h, 1, 3)
    ring2 = chamfer_mask(w, h, 2, 3)
    trough = trough_mask()
    ys, xs = np.mgrid[0:h, 0:w]
    top = ys < h / 2
    rgb[outer] = INK
    a[outer] = 1
    g1 = np.where(top[..., None], np.array(GOLD_HI, float), np.array(GOLD_SH, float))
    g2 = np.where(top[..., None], np.array(GOLD, float), np.array(GOLD_LO, float))
    rgb[ring1] = g1[ring1]
    rgb[ring2] = g2[ring2]
    # 端盖内侧一列墨线，把端盖和槽分开
    for x in (END_CAP - 1, w - END_CAP):
        rgb[TROUGH_INSET:h - TROUGH_INSET, x] = INK
    # 槽：上沿一行内阴影，向下略亮（分级 + 抖动），少量水墨颗粒
    t = quantize_t(np.clip((ys - TROUGH_INSET) / (h - 2 * TROUGH_INSET), 0, 1), 4)
    trough_rgb = lerp((18, 13, 11), (44, 32, 27), t)
    rng = np.random.default_rng(3)
    trough_rgb[rng.random((h, w)) < 0.05] *= 0.8
    rgb[trough] = trough_rgb[trough]
    rgb[TROUGH_INSET, END_CAP:w - END_CAP] = (8, 6, 5)
    # 端盖中央朱红菱形铆钉（6 行高，中心在两行之间）
    for cx in ((END_CAP - 1) / 2, w - 1 - (END_CAP - 1) / 2):
        for y in range(h):
            for x in range(w):
                dd = abs(x - cx) + abs(y - (h - 1) / 2)
                if dd <= 2.6:
                    rgb[y, x] = (214, 58, 40) if dd <= 1.6 else (112, 20, 14)
        rgb[int((h - 1) / 2) - 1, int(round(cx - 0.5))] = (255, 176, 136)
    return up(to_img(rgb, a), BAR_S)


def bar_fill(c0, c1, levels=10, sheen=(255, 236, 196)):
    """与 bar_bg 同尺寸，只在槽内有颜色，可直接叠在 bar_bg 上做 TextureProgressBar。"""
    w, h = BAR_W, BAR_H
    trough = trough_mask()
    ys, xs = np.mgrid[0:h, 0:w]
    t = quantize_t(np.clip((xs - END_CAP) / (w - 2 * END_CAP - 1), 0, 1), levels)
    base = lerp(c0, c1, t)
    r = ys - TROUGH_INSET                     # 槽内行号 0..7
    shade = np.ones((h, w))
    shade[r == 5] = 0.86
    shade[r == 6] = 0.74
    shade[r == 7] = 0.6
    rgb = base * shade[..., None]
    hi = (r == 0)
    rgb[hi] = lerp(base[hi], sheen, 0.55)
    rgb[r == 1] = lerp(base[r == 1], sheen, 0.25)
    # 斜向流光（每 32 格一道像素斜线）
    stripe = ((xs + ys) % 32 < 2) & (r >= 1) & (r <= 4)
    rgb[stripe] = lerp(rgb[stripe], sheen, 0.22)
    return up(to_img(rgb, trough.astype(float)), BAR_S)


def thin_bar(kind):
    w, h = 256, 6                              # 放大 2 倍 = 512x12
    m = chamfer_mask(w, h, 0, 2)
    ys, xs = np.mgrid[0:h, 0:w]
    if kind == "stamina":
        rows = [(255, 246, 212), (246, 226, 160), (236, 206, 128), (228, 196, 116), (196, 158, 78), (150, 114, 50)]
        rgb = np.array([rows[y] for y in range(h)], float)[:, None, :].repeat(w, 1)
        t = quantize_t(xs / (w - 1), 6)
        rgb = rgb * (0.92 + 0.12 * t)[..., None]
        a = m.astype(float)
    else:  # ult：青白，中间两行接近白色，上下两行半透明当光晕
        rows = [(110, 210, 250), (170, 238, 255), (236, 252, 255), (236, 252, 255), (150, 228, 255), (90, 196, 246)]
        alph = [0.55, 0.92, 1, 1, 0.92, 0.5]
        rgb = np.array([rows[y] for y in range(h)], float)[:, None, :].repeat(w, 1)
        a = np.array(alph)[:, None].repeat(w, 1) * m
        # 均匀散布的亮点，增加“发光”感
        rng = np.random.default_rng(11)
        sp = (rng.random((h, w)) < 0.035) & (ys >= 1) & (ys <= 4)
        rgb[sp] = (255, 255, 255)
        pulse = ((xs % 24) < 3) & ((ys == 2) | (ys == 3))
        rgb[pulse] = (255, 255, 255)
    return up(to_img(rgb, a), 2)


# ---- 图标 ---------------------------------------------------------------------
def load_title_font():
    for pattern, full in TITLE_CANDIDATES:
        for p in glob.glob(pattern):
            n = 1
            if p.endswith(".ttc"):
                n = len(TTCollection(p).fonts)
            for idx in range(n):
                try:
                    f = ImageFont.truetype(p, 64, index=idx)
                except OSError:
                    continue
                if " ".join(f.getname()) == full or f.getname()[0] + " " + f.getname()[1] == full:
                    return p, idx, full
    raise RuntimeError("系统里没有可用的书法感中文字体")


def glyph_mask(char, font_path, index, size, canvas):
    img = Image.new("L", (canvas, canvas), 0)
    f = ImageFont.truetype(font_path, size, index=index)
    d = ImageDraw.Draw(img)
    l, t, r, b = d.textbbox((0, 0), char, font=f)
    d.text(((canvas - (r - l)) / 2 - l, (canvas - (b - t)) / 2 - t), char, font=f, fill=255)
    return np.array(img) > 110


def icon(font_path, font_index):
    S = 128
    ys, xs = np.mgrid[0:S, 0:S]
    rr = np.hypot(xs - S / 2 + 0.5, ys - S / 2 + 0.5) / (S * 0.72)
    t = quantize_t(np.clip(rr, 0, 1), 6)
    rgb = lerp((40, 28, 24), (9, 6, 5), t)
    a = np.ones((S, S))

    # 水墨朱红圆（一笔写成的“圆相”，右上留口，带枯笔丝纹）
    cx, cy, R = 64, 66, 47
    ang = np.arctan2(ys - cy, xs - cx)
    dist = np.hypot(xs - cx, ys - cy)
    u = (ang + np.pi * 0.30) % (2 * np.pi) / (2 * np.pi)       # 起笔在右上，顺时针一圈
    width = 3 + 7.5 * np.sin(np.clip(u, 0, 1) * np.pi) ** 0.6
    ring = (np.abs(dist - R) < width / 2) & (u > 0.04) & (u < 0.93)
    rng = np.random.default_rng(5)
    streak_noise = rng.random(400)
    fiber = streak_noise[np.clip(((dist - R + 8) * 18).astype(int), 0, 399)]   # 沿笔触方向的丝纹
    dry = ring & ((fiber > 0.22 + 0.6 * np.clip((u - 0.72) / 0.21, 0, 1)) | (u < 0.7))
    tone = quantize_t(np.clip(np.abs(dist - R) / (width / 2 + 1e-6), 0, 1), 3)
    rgb[dry] = lerp((172, 40, 30), (104, 20, 16), tone)[dry]

    # 方天画戟剪影（左下到右上，压在圆相上、字的后面；戟头放在右上空白处）
    hal = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(hal)
    o = np.array([8.0, 122.0])
    uvec = np.array([1, -1]) / np.sqrt(2)
    vvec = np.array([1, 1]) / np.sqrt(2)

    def P(t_, s_):
        p = o + t_ * uvec + s_ * vvec
        return (float(p[0]), float(p[1]))

    shaft, shaft_lit = (112, 78, 36), (174, 128, 60)
    blade, blade_lit, blade_dk = (206, 180, 122), (252, 236, 182), (132, 102, 56)
    d.polygon([P(0, -1.6), P(132, -1.6), P(132, 1.6), P(0, 1.6)], fill=shaft)
    d.line([P(2, -1.1), P(130, -1.1)], fill=shaft_lit)
    d.polygon([P(-3, -2.6), P(3, -2.6), P(3, 2.6), P(-3, 2.6)], fill=GOLD)              # 戟镦
    for side in (-1, 1):                                                               # 两侧月牙刃
        outer = [P(116 + 20 * k / 14, side * (1.5 + 11.5 * np.sin(np.pi * k / 14))) for k in range(15)]
        inner = [P(136 - 20 * k / 14, side * (1.5 + 5.0 * np.sin(np.pi * k / 14))) for k in range(15)]
        d.polygon(outer + inner, fill=blade)
        d.line(outer[3:12], fill=blade_lit if side < 0 else blade_dk)
    d.polygon([P(132, 0), P(138, -4), P(153, 0), P(138, 4)], fill=blade)               # 枪尖
    d.line([P(134, -0.6), P(151, -0.6)], fill=blade_lit)
    d.polygon([P(126, -2.4), P(130, -2.4), P(130, 2.4), P(126, 2.4)], fill=GOLD_LO)    # 吞口
    ax_, ay_ = P(112, 0)                                                               # 红缨（向下垂）
    d.polygon([(ax_ - 1, ay_), (ax_ + 2, ay_ + 1), (ax_ + 1, ay_ + 10), (ax_ - 4, ay_ + 9)], fill=(186, 34, 26))
    d.polygon([(ax_, ay_ + 1), (ax_ + 2, ay_ + 2), (ax_ + 1, ay_ + 7), (ax_ - 2, ay_ + 7)], fill=(232, 82, 46))
    hal_np = np.array(hal)
    hm = hal_np[..., 3] > 0
    hal_outline = ndimage.binary_dilation(hm, structure=np.ones((3, 3))) & ~hm
    rgb[hal_outline] = INK
    rgb[hm] = hal_np[..., :3][hm]

    # 金色“斗”字：二值化 -> 描边 -> 竖向分级金 -> 倒角高光/暗边 -> 投影
    gm = glyph_mask("斗", font_path, font_index, 104, S)
    gm = np.roll(gm, (2, 1), axis=(0, 1))
    outline = ndimage.binary_dilation(gm, structure=np.ones((3, 3))) & ~gm
    shadow = np.roll(ndimage.binary_dilation(gm, structure=np.ones((3, 3))), (3, 3), axis=(0, 1))
    rgb[shadow] = rgb[shadow] * 0.35
    rgb[outline] = INK
    gy = np.clip((ys - ys[gm].min()) / max(1, ys[gm].max() - ys[gm].min()), 0, 1)
    gold = np.where((quantize_t(gy, 5) < 0.5)[..., None],
                    lerp((252, 226, 150), (226, 174, 76), quantize_t(gy, 5) * 2),
                    lerp((226, 174, 76), (146, 98, 34), quantize_t(gy, 5) * 2 - 1))
    rgb[gm] = gold[gm]
    hi = gm & ~np.roll(gm, (1, 1), axis=(0, 1))
    lo = gm & ~np.roll(gm, (-1, -1), axis=(0, 1))
    rgb[hi] = (255, 244, 200)
    rgb[lo] = (104, 66, 24)

    # 内框：暗金细线 + 四角方块
    fm = np.zeros((S, S), bool)
    fm[4, 4:S - 4] = fm[S - 5, 4:S - 4] = fm[4:S - 4, 4] = fm[4:S - 4, S - 5] = True
    rgb[fm] = (96, 70, 30)
    for (y0, x0) in ((2, 2), (2, S - 7), (S - 7, 2), (S - 7, S - 7)):
        rgb[y0:y0 + 5, x0:x0 + 5] = GOLD_LO
        rgb[y0 + 1:y0 + 4, x0 + 1:x0 + 4] = GOLD
        rgb[y0 + 2, x0 + 2] = GOLD_HI
    return up(to_img(rgb, a), 4)


# ---- 大招横幅底版 -----------------------------------------------------------------
def banner():
    w, h, s = 600, 150, 2                      # 放大 2 倍 = 1200x300
    slant = 36
    ys, xs = np.mgrid[0:h, 0:w]
    off = (h - 1 - ys) * slant / (h - 1)       # 平行四边形：顶边右移
    inside = (xs >= off) & (xs <= w - 1 - slant + off)
    # 角再切一刀（斜切边角）
    cut = 8
    corner = ((xs - off) + ys < cut) | ((w - 1 - slant + off - xs) + (h - 1 - ys) < cut)
    inside &= ~corner
    rng = np.random.default_rng(21)
    # 水墨横向笔触：低频噪声沿 x 拉长
    n = ndimage.gaussian_filter(rng.random((h // 6 + 2, w // 60 + 2)), 0.8)
    n = np.array(Image.fromarray((n * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)) / 255.0
    fine = ndimage.gaussian_filter1d(rng.random((h, w)), 9, axis=1)
    ink = np.clip((n - n.mean()) * 1.8 + (fine - fine.mean()) * 3.0, -1, 1)
    tone = quantize_t(np.clip(0.5 + ink * 0.5, 0, 1), 5)
    rgb = lerp((10, 8, 10), (40, 28, 30), tone)
    alpha = np.where(inside, 0.80 + 0.06 * (tone - 0.5), 0.0)
    # 描边：外圈墨色 1 格，内收 3 格一道金线；底部一条朱红饰带
    edge = inside & ~ndimage.binary_erosion(inside, structure=np.ones((3, 3)))
    inner = ndimage.binary_erosion(inside, iterations=4)
    gold_line = inner & ~ndimage.binary_erosion(inner, structure=np.ones((3, 3)))
    red_band = inside & (ys >= h - 12) & (ys < h - 7) & ~edge
    red_tone = quantize_t(np.clip((xs - off) / (w - slant), 0, 1), 6)
    rgb[red_band] = lerp((150, 26, 20), (220, 70, 38), red_tone)[red_band]
    alpha[red_band] = 0.95
    rgb[gold_line] = np.where((ys < h / 2)[..., None], np.array(GOLD_HI, float), np.array(GOLD, float))[gold_line]
    alpha[gold_line] = 1.0
    rgb[edge] = INK
    alpha[edge] = 1.0
    # 四角各一枚金色菱形角饰（在金线内侧）
    for (cy, cx) in ((9, slant + 14), (9, w - 15), (h - 10, 14), (h - 10, w - 1 - slant - 14)):
        for y in range(cy - 3, cy + 4):
            for x in range(cx - 3, cx + 4):
                dd = abs(x - cx) + abs(y - cy)
                if dd <= 3 and inside[y, x]:
                    rgb[y, x] = GOLD_HI if dd <= 1 else (GOLD if dd <= 2 else GOLD_LO)
                    alpha[y, x] = 1.0
    return up(to_img(rgb, alpha), s)


# ---- 平滑类：晕影 / 尘点 / 星光 / 冲击环 ---------------------------------------------------
def vignette(w=1920, h=1080):
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    nx = (xs - w / 2) / (w / 2)
    ny = (ys - h / 2) / (h / 2)
    r = np.sqrt(nx ** 2 * 0.86 + ny ** 2 * 0.74 + (nx * ny) ** 2 * 0.5)   # 四角更暗
    t = np.clip((r - 0.55) / 0.85, 0, 1)
    a = (t * t * (3 - 2 * t)) * 0.72
    rng = np.random.default_rng(1)
    a = a + (rng.random((h, w)) - 0.5) / 255.0 * 1.5                       # 抖动，消除 8bit 色带
    rgb = np.zeros((h, w, 3))
    rgb[...] = (8, 5, 4)
    return to_img(rgb, np.clip(a, 0, 1))


def dust(size=128):
    ys, xs = np.mgrid[0:size, 0:size].astype(float)
    r = np.hypot(xs - (size - 1) / 2, ys - (size - 1) / 2) / (size / 2)
    a = np.exp(-(r / 0.42) ** 2 * 2.2) * np.clip(1 - r, 0, 1) ** 0.5
    rgb = np.full((size, size, 3), 255.0)
    return to_img(rgb, np.clip(a / a.max(), 0, 1))


def spark(size=64, s=2):
    n = size // s                                        # 32 像素格画，最近邻放大成 64
    c = (n - 1) / 2
    ys, xs = np.mgrid[0:n, 0:n].astype(float)
    dx, dy = np.abs(xs - c), np.abs(ys - c)
    L = n / 2
    taper_h = np.clip(1 - dx / L, 0, 1)
    taper_v = np.clip(1 - dy / L, 0, 1)
    arm_h = taper_h ** 1.5 * np.exp(-(dy / (0.45 + 1.1 * taper_h)) ** 2)
    arm_v = taper_v ** 1.5 * np.exp(-(dx / (0.45 + 1.1 * taper_v)) ** 2)
    r = np.hypot(dx, dy)
    core = np.exp(-(r / 1.6) ** 2)
    glow = np.exp(-(r / 5.5) ** 2) * 0.3
    a = np.clip(np.maximum.reduce([arm_h, arm_v, core]) + glow, 0, 1)
    a = np.round(a * 5) / 5                              # alpha 分 5 级（像素风）
    rgb = np.full((n, n, 3), 255.0)
    tint = np.clip(1 - core * 1.5, 0, 1)                 # 外缘略带暖金
    rgb[..., 2] -= 46 * tint
    rgb[..., 1] -= 14 * tint
    return up(to_img(rgb, a), s)


def ring(size=256):
    c = (size - 1) / 2
    ys, xs = np.mgrid[0:size, 0:size].astype(float)
    r = np.hypot(xs - c, ys - c)
    R, w_in, w_out = size * 0.40, 14.0, 4.5
    d = r - R
    a = np.where(d < 0, np.exp(-(d / w_in) ** 2), np.exp(-(d / w_out) ** 2))
    a *= np.clip((size / 2 - 1 - r) / 3, 0, 1)            # 不碰到图片边缘
    rgb = np.full((size, size, 3), 255.0)
    return to_img(rgb, np.clip(a, 0, 1))


# ---- 字体 ---------------------------------------------------------------------
def fonts():
    os.makedirs(FONTS, exist_ok=True)
    shutil.copyfile(NOTO_SRC, os.path.join(FONTS, "NotoSansSC.ttf"))
    if os.path.exists(OFL_SRC):
        shutil.copyfile(OFL_SRC, os.path.join(FONTS, "NotoSansSC-OFL.txt"))
    path, idx, full = load_title_font()
    out = os.path.join(FONTS, "title.ttf")
    if path.endswith(".ttc"):
        coll = TTCollection(path)
        coll.fonts[idx].save(out)          # fontTools 从 TTC 里抽出单个字形面
    else:
        shutil.copyfile(path, out)          # .otf（CFF）直接拷贝也能用，但扩展名按要求为 .ttf
    # 自检：能加载并且常用字都在
    test = "斗战三国虎牢关吕布关羽张飞赵云马超许褚典韦黄忠胜负单挑必杀"
    f = ImageFont.truetype(out, 48)
    from fontTools.ttLib import TTFont
    cmap = TTFont(out).getBestCmap()
    missing = [ch for ch in test if ord(ch) not in cmap]
    with open(os.path.join(FONTS, "CREDITS.md"), "w", encoding="utf-8") as fh:
        fh.write(
            "# 字体来源\n\n"
            "| 文件 | 来源 | 许可 |\n|---|---|---|\n"
            f"| `assets/fonts/NotoSansSC.ttf` | `打包-斗将三国/assets/fonts/NotoSansSC.ttf` 原样拷贝（可变字体，wght 轴，默认字重 Thin） | "
            "SIL OFL 1.1，许可全文见同目录 `NotoSansSC-OFL.txt`，可商用、可随游戏分发 |\n"
            f"| `assets/fonts/title.ttf` | macOS 系统字体 `{full}`，由 fontTools 从 `{path}` 第 {idx} 个字形面抽出转存为 TTF | "
            "**Apple 系统授权字体，仅限本机开发预览，不能随游戏分发。** 正式发布前请换成可商用的书法字体"
            "（如 OFL 的 马善政毛笔楷书 Ma Shan Zheng、志莽行书 Zhi Mang Xing、刘建毛草 Liu Jian Mao Cao），"
            "文件名保持 `title.ttf` 即可无缝替换 |\n\n"
            f"title.ttf 自检：可被 PIL 加载，测试字串缺字：{''.join(missing) or '无'}。\n"
        )
    return full, path, idx, missing


def main():
    os.makedirs(UI, exist_ok=True)
    font_full, font_path, font_idx, missing = fonts()
    print(f"[font] title.ttf <- {font_full} ({font_path} #{font_idx}) 缺字: {''.join(missing) or '无'}")
    out = {
        "icon.png": icon(font_path, font_idx),
        "bar_bg.png": bar_bg(),
        "bar_fill_p1.png": bar_fill(VERMILION, ORANGE),
        "bar_fill_p2.png": bar_fill(PURPLE, BLUE, sheen=(214, 228, 255)),
        "bar_stamina.png": thin_bar("stamina"),
        "bar_ult.png": thin_bar("ult"),
        "banner.png": banner(),
        "vignette.png": vignette(),
        "dust.png": dust(),
        "spark.png": spark(),
        "ring.png": ring(),
    }
    for name, img in out.items():
        img.save(os.path.join(UI, name), optimize=True)
        print(f"[ui] {name:16s} {img.width}x{img.height}")


if __name__ == "__main__":
    main()
