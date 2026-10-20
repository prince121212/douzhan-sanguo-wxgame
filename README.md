# 斗战三国 · 微信小游戏

虎牢关斗将，横版 1v1 对战。Godot 4 开发，导出为 Web 后经 Brotli 压缩 + 分包改造，跑在微信小游戏平台上。

本仓库是《斗战三国》系列中**微信小游戏**这一支的独立仓库，与同目录下的桌面版、换皮工作区等互不依赖。

---

## 目录结构

```
.
├── wxgame/                 # ★ 微信小游戏成品包，可直接导入开发者工具运行
│   ├── game.js             #    启动入口（宿主垫片 / 触摸桥 / 音频旁路）
│   ├── game.json           #    分包声明：engine / assets
│   ├── project.config.json #    工程配置（AppID 在此）
│   ├── pkg_engine/         #    引擎分包：Godot wasm + 胶水 JS
│   └── pkg_assets/         #    资源分包：index.pck.br
│
├── godot/                  # ★ Godot 源码工程
│   ├── project.godot
│   ├── scenes/             #    场景
│   ├── scripts/            #    GDScript（core / battle / ui）
│   ├── shaders/
│   ├── assets/             #    美术、音频、字体（.import 必须随源文件一起提交）
│   ├── tools/              #    切图、生成背景/UI/音频、脚本检查
│   └── 玩法说明.md          #    玩法与操作说明
│
├── _tools/                 # 构建与验证脚本（见下）
├── tools_mobile/           # 移动端导入调优、Web 冒烟测试
└── _notes/                 # 排查手册、接入计划等工程笔记
```

## 本地运行

### 方式一：微信开发者工具（验证线上形态）

1. 打开微信开发者工具 → 导入项目 → 目录选本仓库的 `wxgame/`
2. AppID 用 `project.config.json` 里的真实 AppID（测试号会被服务端拒绝）
3. 点「编译」，模拟器即启动

命令行等价操作：

```bash
bash _tools/open_ide.sh          # 打开工程并拉起模拟器
bash _tools/verify_ide.sh 60     # 端到端复验：编译 + 实跑 + 读启动日志 + 像素非黑判定
bash _tools/recheck.sh 45        # 改完代码后的快速复验（不重启 IDE）
```

### 方式二：Godot 编辑器（改玩法）

用 Godot 4.7 打开 `godot/` 目录。首次打开会重新导入资源（`godot/.godot/` 是缓存目录，不在仓库里，引擎会自动重建）。

主场景 `scenes/main.tscn`，命令行参数支持 `--duel --pair=a,b`、`--watch`、`--sim=200` 等，详见 `godot/玩法说明.md`。

## 构建流程

```
Godot 导出 Web  →  brotli 压缩 wasm/pck  →  拆成微信分包  →  替换 wxgame/
```

关键脚本：

| 脚本 | 用途 |
|---|---|
| `_tools/export_wxgame.sh` | ★ 日常迭代用：Godot 导出 → brotli → 替换 `wxgame/pkg_assets` → 校验并同步 fileSizes |
| `_tools/verify_build.js` | 用无头浏览器对构建做指标化验收（帧推进、非黑像素占比） |
| `_tools/rollback.sh` | 回滚到指定阶段快照 |
| `godot/tools/check_all.sh` | 全脚本编译检查，必须无 SCRIPT ERROR |

日常迭代只需要跑 `bash _tools/export_wxgame.sh`。

## 平台适配（微信小游戏）

这一支是**只面向微信小游戏**的版本，桌面版的键鼠操作全部改成了触屏：

| 项 | 说明 |
|---|---|
| 触屏操作 | 左手浮动摇杆（推到底=疾跑）+ 右手招式按钮（轻/重/挡/闪/跳/绝）。`battle.gd` 在 `Game.touch_ui` 为真时挂 `touch_controls.gd` |
| 触摸事件 | 小游戏里触摸只能从 `wx.onTouch*` 拿到，而 Godot 胶水是 `canvas.addEventListener('touchstart')`。`game.js` 的 `installTouchBridge()` 负责把两者接起来，否则摇杆按钮全都按不动 |
| 操作提示 | 触屏下不再显示 WASD/J/K/Shift 等键盘键位（标题页、战斗提示、暂停菜单、拼刀提示都已按平台切换文案） |
| 退出游戏 | 触屏下隐藏「退出」按钮——小游戏的退出由平台胶囊按钮负责，`get_tree().quit()` 在小游戏里没有意义 |
| 音量 | 见下 |

## 已知问题与修复

- **微信里完全没声音**：Godot Web 的 WebAudio 节点链到 `destination` 在微信中是哑的。修复在 `wxgame/game.js` 的 `installAudioBypass()`，把音源直连 `ctx.destination`。完整排查思路见 `_notes/微信小游戏音频无声-排查手册.md`。
- **音量滑条调了没反应**（2026-10-21 修复）：旁路最初用固定增益 0.5，绕过了 Godot 的混音总线，于是设置里的音乐/音效音量、BGM 淡入淡出、静音全部失效。现在改为：记录 WebAudio 节点图，播放时从音源 BFS 到 `destination` 取**增益乘积**（最大增益路径，避开单声道踩到 0 增益声道的问题），并每 400ms 重算一次。滑条、淡入淡出、静音因此全部恢复。
- **画面全黑但帧率正常**：`canvasResizePolicy=2` 会读 `window.innerWidth`，小游戏环境没有这个属性 → canvas 变成 0x0。启动日志里的「显示垫片」行可鉴别。
- **宽屏右侧露黑边**（2026-10-21 修复）：所有界面按 1920×1080 排版，全面屏（约 2284×1080）右侧多出的部分会露清屏底色。现在背景用 `Game.cover_rect()` 等比铺满，UI 按 `view_size()` 居中。

## 包体约束

微信小游戏单个分包上限 20MB。当前：

| 包 | 体积 |
|---|---|
| 主包 | ~60 KB |
| `pkg_engine` | ~6.9 MB |
| `pkg_assets` | ~10.0 MB |

资源包余量已不多。若新增武将使 `index.pck.br` 超限，优先压贴图（`_backup/STEP2_OK/build_web_step2` 里有现成的瘦身方案），其次砍立绘走 fallback。

## 代码结构要点

- `godot/scripts/core/game.gd`：全局设置、输入映射、`view_size()` / `cover_rect()` / `ui_offset_y()` 等视口适配工具。
- `godot/scripts/ui/touch_controls.gd`：虚拟摇杆 + 招式按钮，只把触摸翻译成 `p1_*` 动作，战斗逻辑不用感知触屏。
- `godot/scripts/battle/battle.gd`：`request_skip()` / `toggle_speed()` / `toggle_hud()` 是触屏层调用的接口；`prompt_dodge_until` 用来给「闪」按钮高亮。
- `wxgame/game.js`：宿主垫片（canvas/document/fetch/WebAssembly）、触摸桥、音频旁路。**不要改 `pkg_engine/index.js`**，它是 Godot 导出的胶水，重新导出会覆盖。

## 仓库说明

`.gitignore` 排除了构建产物（`build_web*/`）、本地备份快照（`_backup/`）、Godot 编辑器缓存和验证截图——这些都是可重建或一次性的内容。**只有源码、成品小游戏包、脚本和文档入库。**

注意：`wxgame/pkg_assets/index.pck.br` 和 `pkg_engine/index.wasm.br` 是二进制构建产物，每次重新导出都会产生新版本。若迭代频繁导致仓库膨胀，可考虑改为「只存源码，发布时本地导出」。
