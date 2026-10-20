#!/usr/bin/env python3
"""切《斗战三国Q版》小兵助威帧：抠洋红底、裁边、8 帧共用同一画布与锚点。

输入：小兵助威/<兵种>_cheer.png，2 行 x 4 列，读序上排左->右、下排左->右，
是一个连续的助威循环（第 1 帧到第 8 帧）。

抠图与分割直接复用 slice_sheets.py（key_magenta / segment_sheet / foot_line /
weapon_tip），保证和主角色同一套边缘处理。

与主角色不同的是：同一兵种 8 帧必须共用一张画布、一个锚点，否则播放会抖。
对齐方法：
  - 纵向：每帧用 foot_line 找脚底（马蹄）线，统一贴到画布同一条脚底线；
  - 横向：AI 生成的格子里人物左右位置并不固定，所以不用 bbox 居中，而是取
    脚底线往上 30% 身高的下半身（腿、靴、衣摆 / 马腿）做掩码配准，
    以第 1 帧为基准逐像素平移找 IoU 最大的位置，让站着不动的脚不滑步。
输出：assets/troops/<key>/cheer_1..8.png + assets/troops/manifest.json
（字段与 chars/manifest.json 一致：poses.<帧>.anchor/top/tip/size + stand_height，
另加 frames/fps/loop/canvas/anchor 便于直接播放）。

用法：python3 tools/slice_troops.py [源目录] [输出目录]
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.dont_write_bytecode = True   # 不在 tools/ 里留 __pycache__
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slice_sheets import bbox_of, foot_line, segment_sheet, weapon_tip  # noqa: E402  复用主角色逻辑

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SRC = os.path.join(os.path.dirname(ROOT), "斗战三国Q版", "小兵助威")
DEFAULT_OUT = os.path.join(ROOT, "assets", "troops")

TROOPS = {
    "sword_shield_cheer.png": "sword_shield",
    "spear_cheer.png": "spear",
    "archer_cheer.png": "archer",
    "cavalry_cheer.png": "cavalry",
}
MOUNTED = {"cavalry"}
N_FRAMES = 8
FPS = 8            # 生成记录建议 6–8 FPS 试播
MARGIN = 4         # 画布四周留白
LOWER_BODY = 0.30  # 横向配准用的下半身比例
MAX_SHIFT = 80     # 横向配准搜索范围（像素）


def cut_frames(path):
    """返回 8 个 dict：rgba 紧裁剪图、solid 掩码、脚底线 y。"""
    sheet = np.array(Image.open(path).convert("RGBA"))
    seg = segment_sheet(sheet)
    if seg is None:
        raise RuntimeError("整张图没有分割出前景")
    rgb, alpha, labels, owners = seg
    frames = []
    for idx in range(N_FRAMES):
        labs = owners.get(idx)
        if not labs:
            raise RuntimeError(f"第 {idx + 1} 格没找到人物")
        mask = np.isin(labels, labs)
        # 与 slice_sheets.process 相同：把 opening 吃掉的半透明边缘补回来
        mask = ndimage.binary_dilation(mask, iterations=2) & (alpha > 0.02)
        x0, y0, x1, y1 = bbox_of(mask)
        pad = 2
        x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
        x1, y1 = min(sheet.shape[1], x1 + pad), min(sheet.shape[0], y1 + pad)
        crop = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        crop[..., :3] = rgb[y0:y1, x0:x1, :3].astype(np.uint8)
        crop[..., 3] = (alpha[y0:y1, x0:x1] * mask[y0:y1, x0:x1] * 255).astype(np.uint8)
        frames.append({"rgba": crop, "cell_origin": (x0, y0)})
    return frames


def register_x(frames, mounted):
    """以第 1 帧为基准，求每帧下半身掩码 IoU 最大的横向位置，返回每帧锚点 x（裁剪图坐标）。"""
    for f in frames:
        solid = f["rgba"][..., 3] > 110
        f["solid"] = solid
        f["foot"] = foot_line(solid, 20 if mounted else 14)
        f["top"] = int(bbox_of(solid)[1])
    ref = frames[0]
    band = max(16, int((ref["foot"] - ref["top"]) * LOWER_BODY))

    def lower(f):
        return f["solid"][max(0, f["foot"] - band):f["foot"], :]

    ref_low = lower(ref)
    ys, xs = np.nonzero(ref_low)
    ref_ax = int(round(xs.mean()))           # 基准帧锚点：下半身质心
    ref_w = ref_low.shape[1]
    for f in frames:
        low = lower(f)
        if low.shape[0] < ref_low.shape[0]:   # 极少数帧下半身被裁到，补零到同高
            low = np.pad(low, ((ref_low.shape[0] - low.shape[0], 0), (0, 0)))
        best, best_s = -1.0, 0
        w = low.shape[1]
        for s in range(-MAX_SHIFT - ref_w, MAX_SHIFT + w):
            # 帧内容整体相对基准平移 s：比较 low[x] 与 ref_low[x - s]
            a0, a1 = max(0, s), min(w, ref_w + s)
            if a1 - a0 < 8:
                continue
            a = low[:, a0:a1]
            b = ref_low[:, a0 - s:a1 - s]
            inter = np.logical_and(a, b).sum()
            union = low.sum() + ref_low.sum() - inter
            iou = inter / max(1, union)
            if iou > best:
                best, best_s = iou, s
        f["ax"] = ref_ax + best_s
        f["iou"] = round(float(best), 3)
    return ref_ax


def build(path, key, out_dir):
    mounted = key in MOUNTED
    frames = cut_frames(path)
    register_x(frames, mounted)
    # 共用画布：以锚点为原点，取所有帧四个方向的最大伸展
    left = max(f["ax"] for f in frames)
    right = max(f["rgba"].shape[1] - f["ax"] for f in frames)
    up = max(f["foot"] for f in frames)
    down = max(f["rgba"].shape[0] - f["foot"] for f in frames)
    W, H = left + right + 2 * MARGIN, up + down + 2 * MARGIN
    ax, ay = left + MARGIN, up + MARGIN
    os.makedirs(os.path.join(out_dir, key), exist_ok=True)
    poses, report = {}, []
    for i, f in enumerate(frames, start=1):
        canvas = np.zeros((H, W, 4), np.uint8)
        ox, oy = ax - f["ax"], ay - f["foot"]
        h, w = f["rgba"].shape[:2]
        canvas[oy:oy + h, ox:ox + w] = f["rgba"]
        name = f"cheer_{i}"
        Image.fromarray(canvas).save(os.path.join(out_dir, key, name + ".png"), optimize=True)
        solid = canvas[..., 3] > 110
        tip = weapon_tip(solid, ax)
        poses[name] = {
            "anchor": [float(ax), int(ay)],
            "top": int(bbox_of(solid)[1]),
            "tip": [int(tip[0]), int(tip[1])],
            "size": [int(W), int(H)],
        }
        report.append(f"{name}: 贴图偏移({ox},{oy}) 脚底线={f['foot']} 下半身IoU={f['iou']}")
    meta = {
        "poses": poses,
        "stand_height": int(ay - poses["cheer_1"]["top"]),
        # 以下为小兵额外字段
        "frames": list(poses.keys()),
        "fps": FPS,
        "loop": True,
        "canvas": [int(W), int(H)],
        "anchor": [float(ax), int(ay)],
    }
    return meta, report


def main(src_dir, out_dir):
    manifest = {}
    ok = True
    for fname, key in TROOPS.items():
        path = os.path.join(src_dir, fname)
        if not os.path.exists(path):
            print(f"[skip] {fname} 不存在")
            ok = False
            continue
        try:
            meta, report = build(path, key, out_dir)
        except RuntimeError as e:
            print(f"[fail] {fname}: {e}")
            ok = False
            continue
        manifest[key] = meta
        print(f"[ok] {key}: 画布 {meta['canvas'][0]}x{meta['canvas'][1]} 锚点 {meta['anchor']} 身高 {meta['stand_height']}")
        for line in report:
            print("     " + line)
    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=1)
    print(f"共 {len(manifest)} 组 -> manifest.json")
    return ok


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    out = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_OUT
    sys.exit(0 if main(src, out) else 1)
