#!/usr/bin/env python3
"""虎牢关战场背景：原图拷贝 + 两张视差图层 + 视差配置。

hulaoguan_sky.png   1920x540  远景：原图上部（悬崖 / 城墙 / 关楼，y<290）原像素 1:1 放在底部居中；
                    向上用“纹理拼接”把悬崖再长高一截并切出山脊轮廓，后面是程序画的
                    像素风天空、云和两层远山；左右各 124px 用镜像 + 渐进模糊取色扩展。
                    整张左右边缘收敛到同一列颜色，可水平无缝平铺。
hulaoguan_ground.png 2600x1200 近景地面：只取原图中下部空地（无营帐道具），
                    用 Image Quilting（随机取块 + 水平镜像变体 + 重叠区最小误差切缝 + 1px 羽化）
                    铺满，避免镜像轴和重复感；左右首尾再切一道缝，可水平无缝平铺；
                    顶部 48px alpha 羽化，用来压在远景底边上消除接缝。
hulaoguan_parallax.json  每层尺寸、建议视差系数、摆放位置。

纹理拼接：Efros & Freeman 2001 “Image Quilting for Texture Synthesis and Transfer”。
用法：python3 tools/build_bg.py
"""
import json
import os
import shutil

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.signal import fftconvolve

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WS = os.path.dirname(ROOT)
SRC = os.path.join(WS, "斗战三国Q版", "hulaoguan_battle_map.png")
OUT = os.path.join(ROOT, "assets", "bg")

SKY_W, SKY_H = 1920, 540
BAND_H = 290            # 原图上部取到 y=290（城墙底 ~245，关前台阶 ~287）
EXT_H = 160             # 悬崖向上再长 160px
PAD_X = (SKY_W - 1672) // 2
BAND_Y = SKY_H - BAND_H  # 250：原图 y=0 在天空层里的位置
PROTECT_X = (500, 1200)  # 原图顶边这一段有关楼屋脊/旗帜，拼接缝不许切进原图
GROUND_W, GROUND_H, GROUND_FEATHER = 2600, 1200, 48
DIRT_BOX = (250, 320, 1430, 938)   # 原图中下部纯空地 (x0, y0, x1, y1)
CLIFF_BOXES = [(0, 0, 160, 240), (1452, 0, 1672, 155)]   # 左右上角纯悬崖

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], float) / 16.0 + 1 / 32


# ---------------------------------------------------------------------------------
# Image Quilting
# ---------------------------------------------------------------------------------
def dp_cut(err, min_pos=None):
    """err: (depth, L)。返回每列切点 r∈[0, depth]：r 之前保留旧像素，r 起用新块。
    相邻列切点最多差 1，求总误差最小的路径。"""
    depth, L = err.shape
    cost = np.vstack([err, err[-1:]])                    # r=depth 表示整列都保留旧像素
    if min_pos is not None:
        for j in range(L):
            cost[:min_pos[j], j] = 1e15
    acc = cost.copy()
    back = np.zeros(acc.shape, int)
    idx = np.arange(depth + 1)
    for j in range(1, L):
        prev = acc[:, j - 1]
        cand = np.stack([np.r_[np.inf, prev[:-1]], prev, np.r_[prev[1:], np.inf]])
        k = np.argmin(cand, 0)
        acc[:, j] += cand[k, idx]
        back[:, j] = idx + k - 1
    r = np.zeros(L, int)
    r[-1] = int(np.argmin(acc[:, -1]))
    for j in range(L - 1, 0, -1):
        r[j - 1] = back[r[j], j]
    return r


class Quilter:
    def __init__(self, sources, patch, overlap, rng, tol=0.12, search_scale=1, recent=14):
        self.P, self.O, self.rng, self.tol, self.sc = patch, overlap, rng, tol, search_scale
        self.src = [s.astype(np.float64) for s in sources]
        self.small = [self._down(s) for s in self.src]
        self.small_sq = [np.sum(s ** 2, axis=2) for s in self.small]
        self.recent, self.history = recent, []

    def _down(self, img):
        if self.sc == 1:
            return img
        h, w = img.shape[0] // self.sc * self.sc, img.shape[1] // self.sc * self.sc
        return img[:h, :w].reshape(h // self.sc, self.sc, w // self.sc, self.sc, -1).mean((1, 3))

    def pick(self, win, known):
        P, sc = self.P, self.sc
        ps = P // sc
        if not known.any():
            i = int(self.rng.integers(len(self.src)))
            hs, ws = self.src[i].shape[:2]
            return i, int(self.rng.integers(hs - P + 1)), int(self.rng.integers(ws - P + 1))
        M = self._down(known[..., None].astype(float))[..., 0]
        M = (M > 0.5).astype(float)[:ps, :ps]
        Wn = self._down(win)[:ps, :ps]
        maps = []
        for i, (S, S2) in enumerate(zip(self.small, self.small_sq)):
            Mk = M[::-1, ::-1]
            t1 = fftconvolve(S2, Mk, mode="valid")
            t2 = sum(fftconvolve(S[..., c], (M * Wn[..., c])[::-1, ::-1], mode="valid") for c in range(3))
            t3 = float((M[..., None] * Wn ** 2).sum())
            ssd = t1 - 2 * t2 + t3
            # 跟最近用过的位置保持距离，减少重复
            for (hi, hy, hx) in self.history[-self.recent:]:
                if hi == i:
                    y0, x0 = max(0, hy // sc - ps // 2), max(0, hx // sc - ps // 2)
                    ssd[y0:hy // sc + ps // 2, x0:hx // sc + ps // 2] = np.inf
            # 全分辨率块必须完整落在源图里
            hs, ws = self.src[i].shape[:2]
            ssd[(hs - P) // sc + 1:, :] = np.inf
            ssd[:, (ws - P) // sc + 1:] = np.inf
            maps.append(ssd)
        best = max(0.0, min(np.min(m) for m in maps))   # FFT 误差可能让 SSD 略小于 0
        thr = best * (1 + self.tol) + 4.0 * M.sum()
        cands = [(i, y, x) for i, m in enumerate(maps) for y, x in zip(*np.nonzero(m <= thr))]
        i, y, x = cands[int(self.rng.integers(len(cands)))]
        return i, int(y * sc), int(x * sc)

    def place(self, canvas, known, y, x, protect=None):
        P, O = self.P, self.O
        win = canvas[y:y + P, x:x + P]
        kn = known[y:y + P, x:x + P]
        i, sy, sx = self.pick(win, kn)
        self.history.append((i, sy, sx))
        patch = self.src[i][sy:sy + P, sx:sx + P]
        new = np.ones((P, P))
        if kn.any():
            err = np.sum((patch - win) ** 2, axis=2) * kn
            pr = protect[y:y + P, x:x + P] & kn if protect is not None else np.zeros_like(kn)
            if kn[:O].any():
                min_pos = None
                if pr[:O].any():
                    min_pos = [int(np.max(np.nonzero(pr[:O, j])[0]) + 1) if pr[:O, j].any() else 0 for j in range(P)]
                r = dp_cut(err[:O], min_pos)
                for j in range(P):
                    new[:r[j], j] = 0
            if kn[:, :O].any():
                c = dp_cut(err[:, :O].T)
                for k in range(P):
                    new[k, :c[k]] = 0
            alpha = ndimage.gaussian_filter(new, 0.8)        # 切缝羽化 ~1px
            alpha[~kn] = 1.0
            alpha[pr] = 0.0
        else:
            alpha = new
        canvas[y:y + P, x:x + P] = win * (1 - alpha[..., None]) + patch * alpha[..., None]
        known[y:y + P, x:x + P] = True


def grid(total, P, O):
    n = int(np.ceil((total - O) / (P - O)))
    return [k * (P - O) for k in range(n)], O + n * (P - O)


def wrap_x(img, W, O):
    """img 宽 >= W+O：把 [W, W+O) 和 [0, O) 用竖向最小误差缝缝起来，裁成 W 宽，左右可无缝平铺。"""
    head, tail = img[:, :O].copy(), img[:, W:W + O]
    err = np.sum((head - tail) ** 2, axis=2)            # (H, O)
    c = dp_cut(err.T)                                   # 每行切点：c 之前用 tail
    m = np.zeros(err.shape)
    for y, cy in enumerate(c):
        m[y, :cy] = 1.0
    m = ndimage.gaussian_filter(m, 0.8)
    out = img[:, :W].copy()
    out[:, :O] = head * (1 - m[..., None]) + tail * m[..., None]
    return out


# ---------------------------------------------------------------------------------
# 像素风工具
# ---------------------------------------------------------------------------------
def bayer(h, w):
    return np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]


def posterize(t, levels):
    h, w = t.shape
    return np.clip(np.floor(t * (levels - 1) + bayer(h, w)) / (levels - 1), 0, 1)


def gradient_stops(y, stops):
    ys = [s[0] for s in stops]
    cols = np.array([s[1] for s in stops], float)
    return np.stack([np.interp(y, ys, cols[:, c]) for c in range(3)], -1)


def periodic_noise(n, rng, kmin, kmax, amp, power):
    x = np.arange(n)
    out = np.zeros(n)
    for k in range(kmin, kmax + 1):
        out += amp * k ** (-power) * np.cos(2 * np.pi * k * x / n + rng.uniform(0, 2 * np.pi))
    return out


def up2(a):
    return np.repeat(np.repeat(a, 2, 0), 2, 1)


# ---------------------------------------------------------------------------------
# 远景（天空层）
# ---------------------------------------------------------------------------------
def build_sky(orig, rng):
    near = np.zeros((SKY_H, SKY_W, 3))
    opaque = np.zeros((SKY_H, SKY_W), bool)
    band = orig[:BAND_H].astype(float)

    # 1) 悬崖向上长高：在“上下翻转”的空间里做标准拼接（原图顶边 = 已知的上方重叠区）
    P, O = 48, 16
    xs, Wq = grid(1672, P, O)
    ys, Hq = grid(EXT_H + O, P, O)
    canvas = np.zeros((Hq, Wq, 3))
    known = np.zeros((Hq, Wq), bool)
    top_rows = band[:O][::-1]                            # 翻转后：原图 y=O-1..0
    canvas[:O, :1672] = top_rows
    known[:O, :1672] = True
    canvas[:O, 1672:] = top_rows[:, -1:]                 # 右侧多出的几列（最后会裁掉）
    known[:O, 1672:] = True
    protect = np.zeros((Hq, Wq), bool)
    protect[:O, PROTECT_X[0]:PROTECT_X[1]] = True
    sources = []
    for (x0, y0, x1, y1) in CLIFF_BOXES:
        crop = orig[y0:y1, x0:x1].astype(float)[::-1]    # 源也翻转，回到正常空间就是正立的
        sources += [crop, crop[:, ::-1]]                 # + 水平镜像变体
    q = Quilter(sources, P, O, rng, tol=0.15)
    for y in ys:
        for x in xs:
            q.place(canvas, known, y, x, protect)
    ext = canvas[::-1][:, :1672]                         # 翻回正常方向：最下面 O 行 = 原图顶边（可能被缝融合过）
    near[BAND_Y - EXT_H:BAND_Y + O, PAD_X:PAD_X + 1672] = ext[-(EXT_H + O):]
    near[BAND_Y + O:, PAD_X:PAD_X + 1672] = band[O:]
    opaque[BAND_Y - EXT_H:, PAD_X:PAD_X + 1672] = True

    # 2) 两侧：镜像 + 渐进模糊，越往外越糊，并收敛到左右共同的边缘色（可水平平铺）
    y0 = BAND_Y - EXT_H
    center = near[y0:, PAD_X:PAD_X + 1672]
    sigmas = [0, 1.5, 3, 5, 8, 12]
    edge_l = ndimage.gaussian_filter(center[:, :40], (10, 10, 0)).mean(1)
    edge_r = ndimage.gaussian_filter(center[:, -40:], (10, 10, 0)).mean(1)
    target = ndimage.gaussian_filter1d(0.5 * (edge_l + edge_r), 6, axis=0)
    for side in ("L", "R"):
        # strip[:, d] = 以接缝为轴镜像后、距原图 d 像素处的那一列（d=0 紧贴原图）
        strip = center[:, :PAD_X] if side == "L" else center[:, -PAD_X:][:, ::-1]
        stack = [strip if s == 0 else ndimage.gaussian_filter(strip, (s, s, 0), mode="nearest") for s in sigmas]
        out = np.zeros_like(strip)
        for d in range(PAD_X):                           # d=0 紧贴原图
            sig = 12 * (d / (PAD_X - 1)) ** 1.2
            k = np.searchsorted(sigmas, sig)
            k0, k1 = max(0, k - 1), min(len(sigmas) - 1, k)
            f = 0 if k0 == k1 else (sig - sigmas[k0]) / (sigmas[k1] - sigmas[k0])
            col = stack[k0][:, d] * (1 - f) + stack[k1][:, d] * f
            w = np.clip((d - 30) / (PAD_X - 31), 0, 1)
            w = w * w * (3 - 2 * w)
            out[:, d] = col * (1 - w) + target * w
        if side == "L":
            near[y0:, :PAD_X] = out[:, ::-1]
        else:
            near[y0:, PAD_X + 1672:] = out
    opaque[y0:, :] = True

    # 3) 山脊：中间（关口）低、两侧高，周期函数保证左右可平铺；2px 一级台阶
    nb = SKY_W // 2
    xc = np.arange(nb) * 2 + 1
    # 关口在中间：山脊中间低、两侧高（周期 = 图宽，可平铺）
    ridge = 166 + 36 * np.cos(2 * np.pi * (xc - SKY_W / 2) / SKY_W) + periodic_noise(nb, rng, 3, 70, 26, 1.0)
    ridge += rng.normal(0, 1.2, nb)
    ridge = np.clip(ridge, BAND_Y - EXT_H + 6, BAND_Y - 36)
    gate = (xc > PAD_X + 700) & (xc < PAD_X + 1000)
    ridge[gate] = np.minimum(ridge[gate], BAND_Y - 48)   # 关楼屋顶上方至少留 48px 山体
    ridge_b = (np.round(ridge / 2)).astype(int)          # 像素格（2px）坐标
    hb = SKY_H // 2
    yy = np.arange(hb)[:, None]
    mask_b = yy >= ridge_b[None, :]
    er = ndimage.binary_erosion(np.pad(mask_b, ((1, 1), (1, 1)), mode="wrap"),
                                structure=np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]]))[1:-1, 1:-1]
    outline_b = mask_b & ~er
    rim_b = mask_b & ~outline_b & (yy <= ridge_b[None, :] + 1)
    mask, outline, rim = up2(mask_b), up2(outline_b), up2(rim_b)
    alpha = (mask & opaque).astype(float)
    near[rim] = near[rim] * 0.72 + np.array([246, 222, 176]) * 0.28   # 山脊受光边
    near[outline] = (54, 44, 48)

    # 4) 天空 + 云 + 两层远山（像素格 2px）
    yb = np.arange(hb)[:, None].repeat(nb, 1).astype(float)
    sky_t = posterize(np.clip(yb / 125.0, 0, 1), 14)
    sky = gradient_stops(sky_t * 125.0, [(0, (96, 136, 180)), (55, (150, 180, 202)),
                                          (100, (214, 210, 194)), (125, (238, 224, 194))])
    # 云：几团椭圆并集，下沿压暗，上沿提亮；在 ±宽度处重复绘制以便平铺
    cloud = np.zeros((hb, nb), int)
    for (cx, cy, cw, ch) in [(130, 26, 120, 20), (380, 15, 86, 15), (590, 33, 130, 22), (800, 20, 100, 17), (930, 41, 76, 13)]:
        for shift in (-nb, 0, nb):
            for k in range(6):
                ex = cx + shift + (k - 2.5) * cw / 6.5 + rng.uniform(-4, 4)
                ey = cy + rng.uniform(-ch * 0.25, ch * 0.1) - (ch * 0.25 if k in (2, 3) else 0)
                rx, ry = cw / 5.0 * rng.uniform(0.8, 1.2), ch / 2.0 * rng.uniform(0.7, 1.05)
                xx = np.arange(nb)[None, :]
                m = ((xx - ex) / rx) ** 2 + ((yb - ey) / ry) ** 2 <= 1
                m &= yb <= cy + ch * 0.35                # 云底平一点
                cloud[m] = np.maximum(cloud[m], 1)
    cl = cloud > 0
    sky[cl] = (246, 240, 228)
    lower = cl & ~np.roll(cl, -2, axis=0)
    sky[cl & np.roll(~cl, 1, axis=0)] = (255, 252, 244)  # 顶缘高光
    sky[lower | (cl & np.roll(~cl, -4, axis=0))] = (212, 208, 204)

    def range_layer(base, wave, k, phase, amp, top_col, bot_col, rim_col, lo, hi):
        r = base + wave * np.cos(2 * np.pi * k * xc / SKY_W + phase) + periodic_noise(nb, rng, 4, 60, amp, 1.05)
        rb = np.round(np.clip(r, lo, hi) / 2).astype(int)
        m = yb >= rb[None, :]
        t = posterize(np.clip((yb - rb[None, :]) / 45.0, 0, 1), 5)
        col = np.asarray(top_col, float) + (np.asarray(bot_col, float) - np.asarray(top_col, float)) * t[..., None]
        rimm = m & (yb <= rb[None, :])
        col[rimm] = rim_col
        return m, col

    far_m, far_c = range_layer(150, 26, 3, 1.3, 15, (150, 164, 180), (198, 198, 192), (196, 204, 212), 112, 206)
    mid_m, mid_c = range_layer(180, 20, 5, 0.4, 13, (112, 126, 136), (158, 164, 164), (156, 168, 176), 142, 224)
    speck = (rng.random((hb, nb)) < 0.05) & mid_m
    mid_c[speck] *= 0.86
    back = sky.copy()
    back[far_m] = far_c[far_m]
    back[mid_m] = mid_c[mid_m]
    back = up2(back)

    img = back * (1 - alpha[..., None]) + near * alpha[..., None]

    # 5) 关楼屋脊：原图顶边正好切在正脊上，补一道脊线和两端鸱吻
    rx0, rx1 = PAD_X + 768, PAD_X + 904
    dark, tile, lit = np.array([40, 36, 44.0]), np.array([112, 116, 124.0]), np.array([168, 170, 176.0])
    img[BAND_Y - 2:BAND_Y, rx0:rx1] = dark
    for px, dirn in ((rx0, -1), (rx1 - 6, 1)):
        img[BAND_Y - 12:BAND_Y, px:px + 6] = dark
        img[BAND_Y - 10:BAND_Y, px + 2:px + 4] = tile
        img[BAND_Y - 10:BAND_Y - 8, px + 1:px + 5] = lit
        hx = px + (6 if dirn > 0 else -4)
        img[BAND_Y - 14:BAND_Y - 8, hx:hx + 4] = dark       # 向外翘的尾巴
        img[BAND_Y - 12:BAND_Y - 10, hx + 1:hx + 3] = tile
    return np.clip(np.round(img), 0, 255).astype(np.uint8)


# ---------------------------------------------------------------------------------
# 近景地面
# ---------------------------------------------------------------------------------
def build_ground(orig, rng):
    x0, y0, x1, y1 = DIRT_BOX
    dirt = orig[y0:y1, x0:x1].astype(float)
    # 去掉 70% 的大尺度明暗起伏（原图下部略暗），避免拼出来一块深一块浅
    low = ndimage.gaussian_filter(dirt, (60, 60, 0), mode="reflect")
    dirt = np.clip(dirt - 0.7 * (low - dirt.reshape(-1, 3).mean(0)), 0, 255)
    P, O = 112, 36
    xs, Wq = grid(GROUND_W + O, P, O)
    ys, Hq = grid(GROUND_H, P, O)
    canvas = np.zeros((Hq, Wq, 3))
    known = np.zeros((Hq, Wq), bool)
    q = Quilter([dirt, dirt[:, ::-1]], P, O, rng, tol=0.12, search_scale=2)
    for y in ys:
        for x in xs:
            q.place(canvas, known, y, x)
    img = wrap_x(canvas[:GROUND_H], GROUND_W, O)
    rgb = np.clip(np.round(img), 0, 255).astype(np.uint8)
    t = np.clip(np.arange(GROUND_H) / GROUND_FEATHER, 0, 1)
    a = (t * t * (3 - 2 * t) * 255).astype(np.uint8)
    alpha = np.repeat(a[:, None], GROUND_W, 1)
    return np.dstack([rgb, alpha])


def main():
    os.makedirs(OUT, exist_ok=True)
    shutil.copyfile(SRC, os.path.join(OUT, "hulaoguan.png"))
    orig = np.array(Image.open(SRC).convert("RGB"))
    assert orig.shape[:2] == (941, 1672), orig.shape
    rng = np.random.default_rng(20261015)

    sky = build_sky(orig, rng)
    Image.fromarray(sky).save(os.path.join(OUT, "hulaoguan_sky.png"), optimize=True)
    print(f"[bg] hulaoguan_sky.png {sky.shape[1]}x{sky.shape[0]}")
    ground = build_ground(orig, rng)
    Image.fromarray(ground).save(os.path.join(OUT, "hulaoguan_ground.png"), optimize=True)
    print(f"[bg] hulaoguan_ground.png {ground.shape[1]}x{ground.shape[0]}")

    horizon = BAND_Y + 245
    ground_top = SKY_H - GROUND_FEATHER
    cfg = {
        "viewport": [1920, 1080],
        "pixel_scale": 1.0,
        "notes": [
            "坐标以 1920x1080 视口为准，像素与原图 1:1；scroll_scale 对应 Godot 4 Parallax2D.scroll_scale（0=跟屏幕不动，1=跟世界同速）。",
            "推荐两层视差：sky（远）+ ground（近），角色站在 ground 上；sky 与 ground 都可水平无缝平铺（repeat_size.x = 图宽）。",
            f"ground 顶部 {GROUND_FEATHER}px 是 alpha 羽化，按下面的 position 压在 sky 底边上即可消除接缝；z_index 要高于 sky。",
            "不做视差时可以只用 full_scene（原图），等比放大到 1920 宽正好 1920x1080。",
        ],
        "layers": [
            {
                "name": "sky",
                "file": "hulaoguan_sky.png",
                "size": [SKY_W, SKY_H],
                "role": "远景：天空/远山/悬崖/虎牢关城墙",
                "scroll_scale": [0.3, 0.15],
                "position": [0, 0],
                "z_index": -30,
                "repeat_size": [SKY_W, 0],
                "horizon_y": horizon,
                "original_rect_in_layer": [PAD_X, BAND_Y, 1672, BAND_H],
                "generated": {"sky_and_far_mountains": [0, 0, SKY_W, BAND_Y],
                              "side_fill_px": PAD_X, "cliff_extension_px": EXT_H},
            },
            {
                "name": "ground",
                "file": "hulaoguan_ground.png",
                "size": [GROUND_W, GROUND_H],
                "role": "近景地面：角色站立层，横向滚动补边",
                "scroll_scale": [1.0, 1.0],
                "position": [-(GROUND_W - 1920) // 2, ground_top],
                "z_index": -10,
                "repeat_size": [GROUND_W, 0],
                "top_feather_px": GROUND_FEATHER,
                "suggested_floor_y": 900,
            },
            {
                "name": "full_scene",
                "file": "hulaoguan.png",
                "size": [1672, 941],
                "role": "原图整幅（含两侧营寨道具），可选的中景/静态背景",
                "scroll_scale": [0.85, 0.85],
                "position": [0, 0],
                "scale": round(1920 / 1672, 4),
                "z_index": -20,
                "optional": True,
            },
        ],
    }
    with open(os.path.join(OUT, "hulaoguan_parallax.json"), "w", encoding="utf-8") as fh:
        json.dump(cfg, fh, ensure_ascii=False, indent=1)
    print("[bg] hulaoguan_parallax.json")


if __name__ == "__main__":
    main()
