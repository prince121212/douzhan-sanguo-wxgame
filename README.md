# 斗战三国 · 微信小游戏

虎牢关斗将，横版 1v1 对战。Godot 4 开发，导出为 Web 后经 Brotli 压缩 + 分包改造，跑在微信小游戏平台上。

本仓库是《斗战三国》系列中**微信小游戏**这一支的独立仓库，与同目录下的桌面版、换皮工作区等互不依赖。

---

## 目录结构

```
.
├── wxgame/                 # ★ 微信小游戏成品包，可直接导入开发者工具运行
│   ├── game.js             #    启动入口（含启动诊断日志、音频旁路修复）
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
| `_tools/build_brotli.sh` | 从基线产物生成 Brotli 压缩版，并做体积对照与解压校验 |
| `_tools/verify_build.js` | 用无头浏览器对构建做指标化验收（帧推进、非黑像素占比） |
| `_tools/rollback.sh` | 回滚到指定阶段快照 |
| `godot/tools/check_all.sh` | 全脚本编译检查，必须无 SCRIPT ERROR |

导出与替换资源包的完整步骤见 `_notes/新增武将-徐盛-接入计划.md` 的「阶段 G」。

## 已知问题与修复

- **微信里完全没声音**：Godot Web 的 WebAudio 节点链到 `destination` 在微信中是哑的。修复在 `wxgame/game.js` 的 `installAudioBypass()`，把音源直连 `ctx.destination`。完整排查思路见 `_notes/微信小游戏音频无声-排查手册.md`。
- **画面全黑但帧率正常**：`canvasResizePolicy=2` 会读 `window.innerWidth`，小游戏环境没有这个属性 → canvas 变成 0x0。启动日志里的「像素采样」就是用来鉴别这种情况的。

## 包体约束

微信小游戏单个分包上限 20MB。当前：

| 包 | 体积 |
|---|---|
| 主包 | ~128 KB |
| `pkg_engine` | ~6.9 MB |
| `pkg_assets` | ~9.8 MB |

资源包余量已不多。若新增武将使 `index.pck.br` 超限，优先压贴图（`_backup/STEP2_OK/build_web_step2` 里有现成的瘦身方案），其次砍立绘走 fallback。

## 仓库说明

`.gitignore` 排除了构建产物（`build_web*/`）、本地备份快照（`_backup/`）、Godot 编辑器缓存和验证截图——这些都是可重建或一次性的内容。**只有源码、成品小游戏包、脚本和文档入库。**

注意：`wxgame/pkg_assets/index.pck.br` 和 `pkg_engine/index.wasm.br` 是二进制构建产物，每次重新导出都会产生新版本。若迭代频繁导致仓库膨胀，可考虑改为「只存源码，发布时本地导出」。
