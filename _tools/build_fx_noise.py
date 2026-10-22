#!/usr/bin/env python3
"""生成刀光用的噪声图（可平铺，灰度）。

用途：在 shader 里调制刀光内缘，做出「火焰/笔触」的破碎感。
多倍频叠加（fbm），既保留大块的火焰起伏，也带细碎的毛边。
体积很小（约 60KB），可重复生成。
"""
import sys
import random

from PIL import Image

SIZE = 256
# (格子大小, 权重)：小格子 = 高频细碎，大格子 = 低频起伏
OCTAVES = [(8, 0.42), (16, 0.28), (32, 0.19), (64, 0.11)]


def value_noise(seed: int, cell: int) -> list:
    rng = random.Random(seed)
    n = SIZE // cell + 1
    grid = [[rng.random() for _ in range(n)] for _ in range(n)]
    # 平铺：右/下边缘复制第一列/行
    for i in range(n):
        grid[i][n - 1] = grid[i][0]
    for j in range(n):
        grid[n - 1][j] = grid[0][j]
    return grid


def smooth(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)


def sample(grid, cell: int, x: float, y: float) -> float:
    gx, gy = x / cell, y / cell
    x0, y0 = int(gx), int(gy)
    fx, fy = smooth(gx - x0), smooth(gy - y0)
    a = grid[y0][x0] * (1 - fx) + grid[y0][x0 + 1] * fx
    b = grid[y0 + 1][x0] * (1 - fx) + grid[y0 + 1][x0 + 1] * fx
    return a * (1 - fy) + b * fy


def main() -> int:
    out = sys.argv[1] if len(sys.argv) > 1 else "godot/assets/fx/noise_soft.png"
    grids = [(value_noise(7 + i * 13, c), c, w) for i, (c, w) in enumerate(OCTAVES)]
    img = Image.new("L", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            v = sum(sample(g, c, x, y) * w for g, c, w in grids)
            # 提对比：把中间调拉开，边缘才有「啃」的锐度
            v = max(0.0, min(1.0, (v - 0.5) * 1.55 + 0.5))
            px[x, y] = int(v * 255)
    img.save(out)
    print(f"{out}  {SIZE}x{SIZE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
