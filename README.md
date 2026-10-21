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

## 数据配置（数据与代码分离）

**所有可变数值都在 `godot/config/` 的 JSON 里，不在代码里。**

```
godot/config/
├── balance.json       全局平衡（回合时长 / 落马线 / 怒气 / 伤害浮动 / AI 4 档难度）
├── characters.json    武将名册（属性 / 血量 / AI 性格 / 台词）
├── arena.json         战场与时辰光照（换主题只改这里）
├── progression.json   成长系统（评分 / 段位 / 奖章 / 称号 / 掉段）
├── moves/*.json       招式表，按兵器分文件（stand 步战 + mounted 马战，稀疏覆盖 _defaults.json）
└── schema/*.json      数据结构定义（AI 和校验器的共同依据）
```

### 字体（子集）

`godot/assets/fonts/` 里三个字体都是**子集**，只含代码里用到的字（合计约 1.6MB；
全量要 17~24MB）。**新增文案后必须重跑**：

```bash
python3 _tools/build_fonts.py          # 重新生成 + 自检
python3 _tools/build_fonts.py --check  # 只检查
```

不跑会怎样：微信小游戏里没有系统字体兜底（`OS.get_system_fonts()` 返回 0），
新加的字会变成豆腐块。桌面 Godot 反而看不出来，所以这个坑只在微信端暴露。
`export_wxgame.sh` 第一步就会校验字体，缺字直接中止。

写文案时：正文/小字说明用 `UiKit.label(..., title=false)`（思源黑体，字形最全）；
标题/印章/技名才用默认的书法字体。

改数值只需改 JSON，然后：

```bash
python3 _tools/check_config.py    # 结构 + 数值区间 + 引用完整性校验
```

游戏里按 **F9** 可热重载配置，调平衡不用重启。

### 数值控制台（浏览器版，推荐）

**双击项目根目录的 `数值控制台.command`**，会自动打开浏览器。

```
改数值 → 保存 → 点「重新构建」→ 微信开发者工具自动刷新
```

- 保存前**强制跑 `check_config.py`**；校验不通过会自动回滚，坏配置进不了文件
- 「重新构建」= Godot 导出 → brotli → 替换 `wxgame/pkg_assets`，约 25 秒
- 顶部两个指示灯显示 Godot 编辑器 / 微信开发者工具是否在跑
- 支持搜索（`parry`、`关羽`、`unhorse`），分组可折叠，`⌘S` 保存
- 只监听 `127.0.0.1`，不对外网开放

底层就是 `_tools/config_server.py` + `_tools/config_console.html`，零第三方依赖。
也可以手动起：`python3 _tools/config_server.py --port 8770`

> 保存会先跑校验，不通过自动回滚；「重新构建」约 25 秒。
> 关掉那个终端窗口就停止服务（不会常驻后台）。

### 数值控制台（游戏内，备用）

Godot 里运行时按 **F8 / F10** 也能开一个内置控制台（三态锁：解锁 → 确定 → 关锁）。
功能比浏览器版弱（不能搜索、不能批量），适合临时改一两个值。

默认是**锁定**状态（只能看），改动需要四步：

```
点小锁解锁 → 拖动/输入调整 → 点「确定」 → 再点小锁关锁
```

- 只解锁不关锁 = 改动不生效，直接关面板会提示并放弃
- 关锁时才写回 `config/*.json` 并立即 `Cfg.reload()` 生效
- 「还原」把界面恢复成当前生效值（不写文件）
- 整数型字段（体力、属性）写回时保持整数，不会变成 `1290.0`
- 字段列表直接读 `schema/*.schema.json`，schema 加了字段控制台自动出现

**这个控制台只在桌面 Godot 里存在**，`tools/` 目录不会打进微信包，已实测确认。
（微信开发者工具跑的是只读导出包，改不了；要改就用上面的浏览器版。）

为什么需要校验器：招式表是「默认值打底 + 配置覆盖」，**字段名拼错会被静默忽略**
（伤害会悄悄回落到默认值，不报错）。校验器会把它报成「多余字段」。

新增武将 / 换地图主题的完整步骤见 `AGENTS.md`。

## 成长系统（评分 · 段位 · 奖章）

单机打 AI 也会算战绩：每赢一场按表现打分，分数换段位分和奖章。

- **评分**：剩余血量 30 + 用时 25 + 技术（拆招/完美闪避/拼刀）25 + 最高连击 10 + 终结方式 10，满分 100
- **评价**：C / B / A / S / SS / SSS 六档，分数线在 `progression.json` 的 `score.grades`
- **超时判胜**（靠血量占优赢）评价最高只到 B —— 防止为了保血量拖时间
- **段位**：青铜 → 白银 → 黄金 → 白金 → 钻石 → 超凡大师 → 最强王者，每段 3 个小段（III/II/I）
- **输了不扣分、也不给分**；段位分只涨不跌（唯一例外见下面「掉段」）
- **奖章**：永久累计的可消费货币，用来解锁武将、购买称号。花奖章不影响段位分
- **难度门槛**：段位到钻石及以上后，「易」难度不再计分，防止刷简单难度上分
- **掉段**：不靠服务端计时。只记录上次进游戏日期，下次进来做减法——
  每连续 7 天没来掉一个小段，一次最多连掉 5 段（`rank.decay`）

界面入口：主菜单 →「战　绩」（称号佩戴、武将解锁），结算页直接显示本场战报。

存档：微信端走 `wx.setStorageSync`（经 `game.js` 的 `__dzsgStorage` 桥），
桌面端写 `user://progress.json`。启动日志里有一行 `Progress: 微信存档自检 ✅/❌`。

## 代码结构要点

- `godot/scripts/core/game.gd`：全局设置、输入映射、`view_size()` / `cover_rect()` / `ui_offset_y()` 等视口适配工具。
- `godot/scripts/ui/touch_controls.gd`：虚拟摇杆 + 招式按钮，只把触摸翻译成 `p1_*` 动作，战斗逻辑不用感知触屏。
- `godot/scripts/battle/battle.gd`：`request_skip()` / `toggle_speed()` / `toggle_hud()` 是触屏层调用的接口；`prompt_dodge_until` 用来给「闪」按钮高亮。
- `wxgame/game.js`：宿主垫片（canvas/document/fetch/WebAssembly）、触摸桥、音频旁路。**不要改 `pkg_engine/index.js`**，它是 Godot 导出的胶水，重新导出会覆盖。
- `godot/scripts/core/config.gd`：autoload `Cfg`，唯一负责读 JSON 并把 `#RRGGBB` 转成 `Color`、`float` 转成 `int`。
- `godot/scripts/core/roster.gd` / `godot/scripts/battle/moves.gd`：薄壳，只做查询，不含数据。
- `godot/scripts/core/progress.gd`：autoload `Progress`，评分/段位/奖章/称号/掉段的唯一实现，数值全部读 `config/progression.json`。
- `godot/scripts/ui/result_panel.gd`：结算战报（评价印 / 五项评分条 / 段位进度 / 奖章）。
- `godot/scripts/ui/profile_screen.gd`：「战绩」页（段位、称号、武将解锁）。

## 仓库说明

`.gitignore` 排除了构建产物（`build_web*/`）、本地备份快照（`_backup/`）、Godot 编辑器缓存和验证截图——这些都是可重建或一次性的内容。**只有源码、成品小游戏包、脚本和文档入库。**

注意：`wxgame/pkg_assets/index.pck.br` 和 `pkg_engine/index.wasm.br` 是二进制构建产物，每次重新导出都会产生新版本。若迭代频繁导致仓库膨胀，可考虑改为「只存源码，发布时本地导出」。
