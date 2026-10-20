#!/usr/bin/env python3
"""把每个角色的 8 个动作按锚点叠放在同一条脚底线上，检查切换动作时是否跳动。"""
import json
import os
import sys

from PIL import Image, ImageDraw

POSES = ["idle", "walk_l", "walk_r", "windup", "attack", "hurt", "jump", "down"]


def main(chars_dir, out_path, group):
    man = json.load(open(os.path.join(chars_dir, "manifest.json"), encoding="utf-8"))
    keys = [k for k in sorted(man) if k.startswith(group + "/")]
    cell_w, cell_h = 560, 470
    sheet = Image.new("RGBA", (cell_w * len(POSES), cell_h * len(keys)), (46, 36, 28, 255))
    dr = ImageDraw.Draw(sheet)
    for row, key in enumerate(keys):
        poses = man[key]["poses"]
        for col, pose in enumerate(POSES):
            if pose not in poses:
                continue
            info = poses[pose]
            im = Image.open(os.path.join(chars_dir, key, pose + ".png"))
            ox = col * cell_w + 220
            oy = row * cell_h + 440
            ax, ay = info["anchor"]
            sheet.alpha_composite(im, (int(ox - ax), int(oy - ay)))
            dr.line([(ox, row * cell_h + 10), (ox, oy + 20)], fill=(0, 255, 255, 160), width=2)
            dr.line([(col * cell_w + 20, oy), (col * cell_w + cell_w - 20, oy)], fill=(255, 255, 0, 160), width=2)
            tx, ty = info["tip"]
            dr.ellipse([ox - ax + tx - 6, oy - ay + ty - 6, ox - ax + tx + 6, oy - ay + ty + 6], outline=(255, 60, 60, 255), width=3)
    sheet.thumbnail((1800, 4000))
    sheet.convert("RGB").save(out_path)
    print(out_path, sheet.size)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
