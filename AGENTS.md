# AGENTS.md —— 给 AI 的硬性约束

> 这份文件是**新会话的第一份阅读材料**。开始改代码前先读完，能避免 90% 的返工。
> 最后更新：2026-10-21

---

## 一、最重要的一条：数值不许写进业务代码

**所有可变的平衡数值必须来自 `godot/config/` 下的 JSON，禁止在 `.gd` 里写字面量。**

```gdscript
# ❌ 禁止
var dmg := 98.0
if hp / max_hp < 0.55:

# ✅ 正确
var dmg := Cfg.bal_float("damage.base_heavy", 98.0)
if hp / max_hp < Cfg.bal_float("round.unhorse_hp_ratio", 0.55):
```

判断标准：**这个数字会不会被策划/AI 反复调整？**
- 会 → 进配置
- 不会（物理常量 `GRAVITY`、UI 坐标、特效手感 `shake`）→ 留在代码里

改完配置**必须**跑：

```bash
python3 _tools/check_config.py
```

---

## 二、配置目录结构

```
godot/config/
├── balance.json              全局平衡参数（回合时长/落马线/怒气/伤害浮动/AI 难度）
├── characters.json           武将名册（属性/血量/AI 性格/台词）
├── arena.json                战场与时辰光照
├── moves/
│   ├── _defaults.json        招式默认值（所有招式共享）
│   ├── spear.json            按兵器分文件：stand（步战）+ mounted（马战）
│   └── ...（glaive/snake/cleaver/dual/bow/halberd）
└── schema/
    ├── balance.schema.json   ← 数据结构定义，改字段必须同步改这里
    ├── characters.schema.json
    ├── arena.schema.json
    └── moves.schema.json
```

**Schema 是唯一权威**。新增字段的流程：
1. 先改 `schema/*.schema.json`
2. 再改对应 `.json` 数据
3. 跑校验器

---

## 三、几条不能违反的约定

### 1. 招式表是稀疏的
`moves/*.json` 里每个招式**只写与 `_defaults.json` 不同的字段**。
不要为了"完整"把所有 42 个字段都抄一遍——那样改默认值就不生效了。

### 2. 字段名拼错是静默的
招式表是「默认值打底 + 配置覆盖」，拼错的键会被当成新键忽略，真正的字段取默认值。
**这正是 `check_config.py` 存在的原因**——它会把多余键报成错误。
永远不要跳过校验。

### 3. 新增武将的完整清单
1. 切图放到 `godot/assets/chars/stand/<id>/` 和 `mount/<id>/`
2. 跑 `python3 godot/tools/slice_sheets.py`（生成 manifest）
3. 在 `config/characters.json` 的 `characters` 里加一条 + 写进 `order`
4. 如果用了新兵器：加 `config/moves/<weapon>.json`
5. 如果用了新绝技演出：在 `ultimates.gd` 加 match 分支 + 更新 schema 的 `ult.id` enum
6. 跑校验器 + `--touchtest` + 出图确认

### 4. 换地图主题
只改 `config/arena.json`：
- `arenas` 里加一个条目（`map` / `ground` / `size` / `presets`）
- 兵卒和旗帜的摆位是**按地图尺寸百分比**算的，换尺寸会自动跟着缩放
- `size` 改了，镜头边界、角色活动范围都会自动跟着变

### 5. Color 用 `#RRGGBB` 字符串
JSON 没有 Color 类型。`Cfg.to_color()` 负责转换，写错格式会显示成品红色（一眼能看出来）。

### 6. JSON 不能写注释
说明文字写在 `schema` 的 `description` 里，或者用 `"_comment"` 字段（校验器会跳过 `_` 开头的键）。

---

## 四、验证顺序（改完必跑）

```bash
# 1. 配置校验（最快，几秒）
python3 _tools/check_config.py

# 2. 脚本编译 + 触屏自检
cd godot && "$GODOT" --path . -- --touch --touchtest --duel --pair=zhaoyun,lvbu

# 3. 出图看效果（宽屏 + 4:3 各一张）
cd godot && "$GODOT" --path . -- --touch --duel --winsize=2284x1080 --shots=2,3,/tmp/shots

# 4. 平衡回归（可选，改数值后建议跑）
cd godot && "$GODOT" --headless --path . --fixed-fps 60 -- --sim=20

# 5. 导出到微信包
bash _tools/export_wxgame.sh
```

---

## 五、别碰的东西

| 文件 | 原因 |
|---|---|
| `wxgame/pkg_engine/index.js` | Godot 导出的胶水，重新导出会覆盖 |
| `godot/.godot/` | 编辑器缓存，已 gitignore |
| `godot/assets/**/*.import` | Godot 4 靠它定位资源，必须提交但别手改 |

---

## 六、当前已知的「暂时还没配置化」清单

这些是**已知遗留**，不是遗漏。改动它们时按需迁移，不必一次性做完：

- `fighter.gd` 的物理常量（`GRAVITY` / `STAND_HW` / `MOUNT_HW`）—— 属于引擎手感，不打算配置化
- 招式里的 `tilt_*` / `shake` / `hitstop` / `arc` / `sfx_*` —— 属于美术手感，schema 里标了 `tier: "feel"`
- `battle.gd` 的演出时序（慢动作时长、镜头推拉）—— 属于演出节奏
- UI 布局坐标 —— 属于界面设计

**如果某个数值被反复调整了 3 次以上，就把它迁进配置。**
