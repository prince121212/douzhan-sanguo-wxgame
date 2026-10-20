#!/usr/bin/env python3
"""小游戏版：只改图片的 .import 参数，源图和代码都不动。
- 所有 png：关 mipmap
- 武将/兵卒/切入/背景：改成有损压缩（导出到 pck 里是 WebP lossy），体积大幅下降
- 背景：import 时限制最长边（arena.gd 按贴图实际尺寸算缩放，所以不影响画面布局）
- 武将/兵卒不缩尺寸：manifest.json 里的锚点、刀尖坐标都是按原图像素写的
- ui 小图保持无损，避免描边和血条出现压缩痕迹
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "godot" / "assets"
LOSSY_DIRS = ("chars", "troops", "cutin", "bg")
SIZE_LIMIT = {"bg": 1600, "cutin": 1024}
QUALITY = 0.82


def set_param(text: str, key: str, value: str) -> str:
    pat = re.compile(r"^" + re.escape(key) + r"=.*$", re.M)
    if pat.search(text):
        return pat.sub(f"{key}={value}", text)
    return text.rstrip("\n") + f"\n{key}={value}\n"


def main() -> int:
    n = 0
    for imp in sorted(ROOT.rglob("*.png.import")):
        top = imp.relative_to(ROOT).parts[0]
        t = imp.read_text(encoding="utf-8")
        t = set_param(t, "mipmaps/generate", "false")
        if top in LOSSY_DIRS:
            t = set_param(t, "compress/mode", "1")
            t = set_param(t, "compress/lossy_quality", str(QUALITY))
        if top in SIZE_LIMIT:
            t = set_param(t, "process/size_limit", str(SIZE_LIMIT[top]))
        imp.write_text(t, encoding="utf-8")
        n += 1
    print(f"updated {n} png imports")
    return 0


if __name__ == "__main__":
    sys.exit(main())
