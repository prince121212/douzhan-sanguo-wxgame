#!/usr/bin/env python3
"""把《斗战三国Q版》的形象图切帧、抠底、算锚点。

输入：2 行 x 4 列，8 个动作（待机/左步/右步/蓄力/攻击/受击/跳跃/倒地），洋红底。
长兵器经常伸进相邻格子，所以不按格子硬切，而是按连通域分割：
每个人物（连同兵器）是一整块，按质心落在哪一格归属到哪个动作。

输出：每个动作一张紧裁剪的透明 PNG；manifest.json 记录锚点
（脚底点 / 头部中心 / 兵器尖），游戏里以锚点为原点摆放，切换动作时人物不会跳。

用法：python3 slice_sheets.py <源目录> <输出目录>
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

POSE_NAMES = ["idle", "walk_l", "walk_r", "windup", "attack", "hurt", "jump", "down"]

STANDING = {
    "zhaoyun_actions.png": "zhaoyun",
    "guanyu_actions.png": "guanyu",
    "zhangfei_actions.png": "zhangfei",
    "machao_actions.png": "machao",
    "xuchu_actions.png": "xuchu",
    "dianwei_actions.png": "dianwei",
    "huangzhong_actions.png": "huangzhong",
    "lvbu_actions.png": "lvbu",
    "xusheng_actions.png": "xusheng",
}
MOUNTED = {
    "zhaoyun_mounted_actions.png": "zhaoyun",
    "guanyu_mounted_actions.png": "guanyu",
    "zhangfei_mounted_actions.png": "zhangfei",
    "machao_mounted_actions.png": "machao",
    "xuchu_mounted_actions.png": "xuchu",
    "dianwei_mounted_actions.png": "dianwei",
    "huangzhong_mounted_actions.png": "huangzhong",
    "lvbu_mounted_actions.png": "lvbu",
    "xusheng_mounted_actions.png": "xusheng",
}


def key_magenta(rgba):
    """洋红底 -> alpha。返回 (rgba, alpha_float)。边缘做去溢色，避免粉边。"""
    arr = rgba.astype(np.float32)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    mag = np.minimum(r, b) - g  # 品红程度
    # 纯背景：红蓝都高、绿低
    bg = (mag > 70) & (r > 110) & (b > 110)
    # 过渡带：部分透明
    alpha = np.ones_like(r)
    soft = (mag > 35) & (r > 90) & (b > 90) & ~bg
    alpha[soft] = np.clip(1.0 - (mag[soft] - 35) / 40.0, 0.0, 1.0)
    alpha[bg] = 0.0
    alpha *= arr[..., 3] / 255.0

    # 去溢色：只处理背景附近 3px 内的像素
    near_bg = ndimage.binary_dilation(bg, iterations=3) & ~bg
    spill = np.clip(np.minimum(r, b) - g, 0, None)
    k = np.where(near_bg, 0.85, 0.0)
    out = arr.copy()
    out[..., 0] = r - k * spill
    out[..., 2] = b - k * spill
    out = np.clip(out, 0, 255)
    return out, alpha


def bbox_of(mask):
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def foot_line(mask, min_count=16):
    """从下往上找第一行“有分量”的像素行，作为脚底/马蹄线（忽略细长的枪杆尾）。"""
    counts = mask.sum(axis=1)
    rows = np.nonzero(counts >= min_count)[0]
    if len(rows) == 0:
        rows = np.nonzero(counts)[0]
    return int(rows.max()) + 1


def segment_sheet(rgba_np, cols=4, rows=2):
    rgb, alpha = key_magenta(rgba_np)
    fg = alpha > 0.45
    # 去掉孤立噪点
    fg = ndimage.binary_opening(fg, structure=np.ones((2, 2)))
    labels, n = ndimage.label(fg, structure=np.ones((3, 3)))
    if n == 0:
        return None
    idx = np.arange(1, n + 1)
    areas = ndimage.sum(fg, labels, idx)
    centroids = ndimage.center_of_mass(fg, labels, idx)
    slices = ndimage.find_objects(labels)
    h, w = fg.shape
    cw, ch = w / cols, h / rows
    big_thresh = max(areas) * 0.06

    owners = {}  # cell -> [label ids]
    small = []
    for i, (area, (cy, cx), sl) in enumerate(zip(areas, centroids, slices), start=1):
        if area < 25:
            continue
        if area >= big_thresh:
            cell = int(min(rows - 1, cy // ch)) * cols + int(min(cols - 1, cx // cw))
            owners.setdefault(cell, []).append(i)
        else:
            small.append((i, sl))

    # 小碎片（速度线、汗珠）就近并入大块
    def bbox_dist(sa, sb):
        ay0, ay1, ax0, ax1 = sa[0].start, sa[0].stop, sa[1].start, sa[1].stop
        by0, by1, bx0, bx1 = sb[0].start, sb[0].stop, sb[1].start, sb[1].stop
        dx = max(0, max(ax0, bx0) - min(ax1, bx1))
        dy = max(0, max(ay0, by0) - min(ay1, by1))
        return (dx * dx + dy * dy) ** 0.5

    for lab, sl in small:
        best, best_d = None, 1e9
        for cell, labs in owners.items():
            for big in labs:
                d = bbox_dist(sl, slices[big - 1])
                if d < best_d:
                    best, best_d = cell, d
        if best is not None and best_d < 70:
            owners[best].append(lab)

    return rgb, alpha, labels, owners


def head_anchor_x(mask):
    """站姿：大头是最稳定的特征，取上半部分像素质心。"""
    x0, y0, x1, y1 = bbox_of(mask)
    top = mask[y0:y0 + max(1, int((y1 - y0) * 0.5)), :]
    ys, xs = np.nonzero(top)
    return float(xs.mean())


def body_anchor_x(mask, part):
    x0, y0, x1, y1 = bbox_of(mask)
    hgt = y1 - y0
    if part == "bottom":
        sub = mask[y0 + int(hgt * 0.5):y1, :]
    else:
        sub = mask[y0:y1, :]
    ys, xs = np.nonzero(sub)
    return float(xs.mean())


def weapon_tip(mask, anchor_x):
    """朝右的最远点（兵器尖），返回相对坐标。"""
    ys, xs = np.nonzero(mask)
    right = xs.max()
    col = ys[xs >= right - 2]
    return int(right), int(np.median(col))


def process(path, mounted):
    sheet = np.array(Image.open(path).convert("RGBA"))
    seg = segment_sheet(sheet)
    if seg is None:
        return None
    rgb, alpha, labels, owners = seg
    poses = {}
    for idx, pose in enumerate(POSE_NAMES):
        labs = owners.get(idx)
        if not labs:
            print(f"   [warn] {os.path.basename(path)} 第{idx + 1}格({pose})没找到人物")
            continue
        mask = np.isin(labels, labs)
        # 把被 opening 吃掉的半透明边缘补回来
        mask = ndimage.binary_dilation(mask, iterations=2) & (alpha > 0.02)
        x0, y0, x1, y1 = bbox_of(mask)
        pad = 12
        x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
        x1, y1 = min(sheet.shape[1], x1 + pad), min(sheet.shape[0], y1 + pad)
        crop_mask = mask[y0:y1, x0:x1]
        crop = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        crop[..., :3] = rgb[y0:y1, x0:x1, :3].astype(np.uint8)
        crop[..., 3] = (alpha[y0:y1, x0:x1] * crop_mask * 255).astype(np.uint8)

        solid = crop[..., 3] > 110
        if pose == "down":
            ax = body_anchor_x(solid, "all")
        elif mounted:
            ax = body_anchor_x(solid, "bottom")
        else:
            ax = head_anchor_x(solid)
        ay = foot_line(solid, 14 if not mounted else 20)
        bx0, by0, bx1, by1 = bbox_of(solid)
        tip = weapon_tip(solid, ax)
        poses[pose] = {
            "image": Image.fromarray(crop, "RGBA"),
            "anchor": [round(ax, 1), ay],
            "top": int(by0),
            "tip": [tip[0], tip[1]],
            "size": [crop.shape[1], crop.shape[0]],
        }
    return poses


def main(src_dir, out_dir):
    manifest = {}
    for table, sub, mounted in ((STANDING, "stand", False), (MOUNTED, "mount", True)):
        for fname, key in sorted(table.items()):
            path = os.path.join(src_dir, fname)
            if not os.path.exists(path):
                print(f"[skip] {fname} 不存在")
                continue
            poses = process(path, mounted)
            if not poses:
                print(f"[fail] {fname}")
                continue
            out_sub = os.path.join(out_dir, sub, key)
            os.makedirs(out_sub, exist_ok=True)
            meta = {}
            for pose, info in poses.items():
                info["image"].save(os.path.join(out_sub, f"{pose}.png"), optimize=True)
                meta[pose] = {k: v for k, v in info.items() if k != "image"}
            idle = meta.get("idle")
            manifest[f"{sub}/{key}"] = {
                "poses": meta,
                # 待机姿势从头顶到脚底的高度，用来统一角色比例
                "stand_height": (idle["anchor"][1] - idle["top"]) if idle else 0,
            }
            print(f"[ok] {sub}/{key}: {len(meta)} 个动作, 身高 {manifest[f'{sub}/{key}']['stand_height']}")
    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=1)
    print(f"共 {len(manifest)} 组 -> manifest.json")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
