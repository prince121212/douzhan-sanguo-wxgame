# 字体来源

全部为 SIL Open Font License 1.1，可商用、可随游戏分发。

| 文件 | 字体 | 用途 | 许可 |
|---|---|---|---|
| `brush.ttf` | 马善政毛笔楷书 Ma Shan Zheng | 标题、印章大字（战/斩/拆招）、绝技名 | OFL 1.1，见 `brush-OFL.txt` |
| `serif.ttf` | 霞鹜文楷 LXGW WenKai Medium | 武将名号、战报、对白、按钮 | OFL 1.1，见 `serif-OFL.txt` |
| `NotoSansSC.ttf` | 思源黑体 Noto Sans SC（可变字重，游戏里用 560） | 数字、小字说明、缺字回退 | OFL 1.1，见 `NotoSansSC-OFL.txt` |

说明：最初用过的 ZCOOL XiaoWei 缺「回」字（显示成方块），已换成霞鹜文楷；macOS 系统楷体不能随游戏分发，已删除。

**这三个文件都是子集**（只含代码/配置里实际用到的字，合计约 1.6MB；全量 17~24MB）。
新增文案后必须跑 `python3 _tools/build_fonts.py` 重新生成，否则新字在微信里会变豆腐块
（微信小游戏没有系统字体兜底）。生成脚本从 `../斗战三国/assets/fonts/` 的全量字体切子集。
