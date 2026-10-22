# 战斗特效素材来源

## 刀光贴图 `assets/fx/slash/arc_wide.png`、`arc_thin.png`

- **作品**：Slash Effect Collection
- **作者**：Cethiel
- **来源**：https://opengameart.org/content/slash-effect-collection
- **许可**：CC0 1.0（公有领域，可商用、可修改、无需署名）
- **改动**：裁掉透明边、放大 2 倍、转为纯白并把亮度写入 alpha，
  以便用 shader 的 tint 跟随各武将的主题色染色。
- **再生成**：`python3 _tools/build_fx_assets.py --src <解压后的 Slash Effect Collection 目录>`

## 参考过的其他项目（未直接使用代码或素材）

| 项目 | 许可 | 结论 |
|---|---|---|
| [gdquest-demos/godot-4-VFX-assets](https://github.com/gdquest-demos/godot-4-VFX-assets) | 素材各自授权 | 只有爆炸/拖尾/涡流，没有 2D 刀光 |
| [haowg/GODOT-VFX-LIBRARY](https://github.com/haowg/GODOT-VFX-LIBRARY) | MIT | 全是 CPUParticles2D 粒子（火花/烟雾），无挥砍弧 |
| [Kelpekk/Juicee](https://github.com/Kelpekk/Juicee) | MIT | 打击感工具（震屏/缩放），不含刀光贴图 |
| [gtibo/VFX-sketchbook-Godot-4.x](https://github.com/gtibo/VFX-sketchbook-Godot-4.x) | 无许可文件 | **不能商用**，未使用 |
| [Anipixels/crisp-juice-free](https://github.com/Anipixels/crisp-juice-free) | 代码 MIT / 贴图自定义 | 休闲风（金币/彩带），风格不符 |

结论：2D 刀光这一块，开源代码库基本都是「拖尾」或「粒子」，真正能用的是一张手绘弧贴图 +
按角度揭示的 shader。所以最终是 **CC0 素材 + 自写 shader** 的组合。

## 刀光带 shader `scripts/battle/fx/slash_ribbon.gdshader`

- **参考**：REEBOO Stylized VFX (Free) 的 `vfx_slash.gdshader`
- **作者**：reeboolabs
- **来源**：https://github.com/reeboolabs/reeboo-stylized-vfx-free
- **许可**：MIT
- **改动**：3D `spatial` shader 改写为 2D `canvas_item`；
  带状网格改为按判定弧程序化生成（月牙剖面 + 两端收尖）；
  新增内缘噪声烧蚀、四段色阶、刃口白热、独立加法光晕层。
  噪声图 `assets/fx/noise_soft.png` 由 `_tools/build_fx_noise.py` 生成（原创，无版权问题）。

## 噪声图 `assets/fx/noise_soft.png`

- 由 `_tools/build_fx_noise.py` 程序生成（4 倍频值噪声 + 对比拉伸）
- 可平铺 256×256 灰度，无外部素材来源

## 突刺光 `scripts/battle/fx/thrust_streak.gd`

- **原创**（无外部素材）。程序化多层多边形：外焰 / 主焰 / 亮芯 / 刃芯 + 尖端星芒。
- **踩过的坑（务必注意）**：`assets/fx/slash/arc_thin.png` 是 **4 帧序列**（`Big/Slash Gradual.png`
  的第 2 帧导出时未做列切分），不是单个月牙。任何「按单月牙圆心算角度」的 shader
  （如 `slash_reveal.gdshader`）套上去都会切出从图片中心发散的硬边楔形。
  突刺已改回程序化锥形光刃，不再使用该贴图；`slash_tex.gd` 仍保留供 `slashspr` 调试用。
