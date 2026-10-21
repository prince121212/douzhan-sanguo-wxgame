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
