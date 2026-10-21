#!/usr/bin/env python3
"""
配置校验器 —— 数据分离方案的「守门人」
============================================================================
为什么必须有它：
  Moves 的招式表是「DEFAULTS 打底 + 配置覆盖」。字段名拼错时，
  拼错的那个键会被当成新键静默忽略，真正的字段仍取默认值 ——
  不报错、不警告，伤害悄悄从 98 变成 40。这类 bug 靠肉眼几乎不可能发现。

本脚本做的事：
  1. 结构校验：必填字段、多余字段（拼错）、类型、枚举值
  2. 数值校验：超出 schema 里 range 的给出警告（防手滑多打一个 0）
  3. 引用完整性：next / heavy_next 指向的招式必须存在；
                 weapon 必须有对应的 moves/<weapon>.json；
                 ult.id 必须有实现；order 里的 id 必须存在
  4. 一致性：characters 里的武将必须在 order 里（或反过来）

退出码：0 = 通过（可能有警告）；1 = 有错误。

用法：
  python3 _tools/check_config.py
  python3 _tools/check_config.py --strict     # 警告也算失败
============================================================================
"""
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CFG = ROOT / "godot" / "config"
SCHEMA = CFG / "schema"

errors = []
warnings = []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def load(p):
    try:
        with open(p, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        err(f"文件不存在: {p.relative_to(ROOT)}")
        return {}
    except json.JSONDecodeError as e:
        err(f"JSON 语法错误 {p.relative_to(ROOT)}: 第 {e.lineno} 行 {e.msg}")
        return {}


def check_keys(where, obj, schema_props, required=()):
    """检查多余字段（拼写错误最常见）与必填字段"""
    for k in obj:
        if k.startswith("_"):
            continue
        if k not in schema_props:
            err(f"{where}: 多余字段「{k}」（schema 里没有，八成是拼错了）")
    for k in required:
        if k not in obj:
            err(f"{where}: 缺少必填字段「{k}」")


def check_range(where, key, value, spec):
    rng = spec.get("range")
    if rng and isinstance(value, (int, float)) and not isinstance(value, bool):
        lo, hi = rng
        if value < lo or value > hi:
            warn(f"{where}.{key} = {value} 超出建议区间 [{lo}, {hi}]（防手滑，不一定是错）")


def check_type(where, key, value, spec):
    t = spec.get("type")
    if t is None:
        return
    ok = {
        "string": isinstance(value, str),
        "number": isinstance(value, (int, float)) and not isinstance(value, bool),
        "integer": isinstance(value, int) and not isinstance(value, bool),
        "boolean": isinstance(value, bool),
        "array": isinstance(value, list),
        "object": isinstance(value, dict),
    }.get(t)
    if ok is False:
        err(f"{where}.{key} 类型应为 {t}，实际是 {type(value).__name__}")
    enum = spec.get("enum")
    if enum and value not in enum:
        err(f"{where}.{key} = {value!r} 不在允许值 {enum} 中")


# ---------------------------------------------------------------- 招式
def check_moves():
    schema = load(SCHEMA / "moves.schema.json")
    move_spec = schema.get("definitions", {}).get("move", {})
    move_props = move_spec.get("properties", {})
    move_required = move_spec.get("required", [])

    moves_dir = CFG / "moves"
    defaults = load(moves_dir / "_defaults.json").get("defaults", {})
    if not defaults:
        err("moves/_defaults.json 缺少 defaults")
    else:
        # 默认值本身也要校验：它是最容易改错又最不容易被发现的地方
        # （改错一个键名 → 所有招式一起静默回落到旧值）
        check_keys("moves/_defaults.json", defaults, move_props)
        for k, v in defaults.items():
            spec = move_props.get(k)
            if spec:
                check_type("moves/_defaults.json", k, v, spec)
                check_range("moves/_defaults.json", k, v, spec)
        # 必填字段不能只存在于默认值里就"看起来"齐全——必须在每个招式里显式给出？
        # 不必：默认值提供合法初值正是设计意图。但默认值自己不能缺 required 里的类型

    weapons = set()
    total = 0
    for f in sorted(moves_dir.glob("*.json")):
        if f.name.startswith("_"):
            continue
        data = load(f)
        weapon = data.get("weapon", f.stem)
        weapons.add(weapon)
        if weapon != f.stem:
            err(f"moves/{f.name}: weapon 字段({weapon}) 与文件名({f.stem}) 不一致")
        for stance in ("stand", "mounted"):
            if stance not in data:
                err(f"moves/{f.name}: 缺少 {stance}")
                continue
            moveset = data[stance]
            if not isinstance(moveset, dict):
                err(f"moves/{f.name}.{stance}: 应为对象")
                continue
            for mname, mv in moveset.items():
                where = f"{weapon}/{stance}.{mname}"
                total += 1
                check_keys(where, mv, move_props, move_required)
                for k, v in mv.items():
                    spec = move_props.get(k)
                    if spec:
                        check_type(where, k, v, spec)
                        check_range(where, k, v, spec)
                # 引用完整性
                for link in ("next", "heavy_next"):
                    target = mv.get(link, "")
                    if target and target not in moveset:
                        err(f"{where}.{link} = 「{target}」 指向不存在的招式")

    # 武将引用的 weapon 必须有招式文件
    chars = load(CFG / "characters.json")
    for cid, c in chars.get("characters", {}).items():
        w = c.get("weapon")
        if w and w not in weapons:
            err(f"武将 {cid} 的 weapon=「{w}」没有对应的 config/moves/{w}.json")
    print(f"  招式: {total} 招 / {len(weapons)} 兵器")


# ---------------------------------------------------------------- 武将
def check_characters():
    schema = load(SCHEMA / "characters.schema.json")
    defs = schema.get("definitions", {})
    char_spec = defs.get("character", {})
    cprops = char_spec.get("properties", {})
    char_required = char_spec.get("required", [])

    data = load(CFG / "characters.json")
    chars = data.get("characters", {})
    order = data.get("order", [])

    ult_ids = set(defs.get("character", {}).get("properties", {})
                  .get("ult", {}).get("properties", {})
                  .get("id", {}).get("enum", []))
    ai_spec = cprops.get("ai", {})
    ai_props = ai_spec.get("properties", {})
    ai_required = ai_spec.get("required", [])
    stats_spec = cprops.get("stats", {})
    stats_props = stats_spec.get("properties", {})
    stats_required = stats_spec.get("required", [])

    for cid, c in chars.items():
        where = f"characters.{cid}"
        check_keys(where, c, cprops, char_required)
        for k, v in c.items():
            spec = cprops.get(k)
            if not spec:
                continue
            if k in ("stats", "ai", "ult", "lines"):
                continue
            check_type(where, k, v, spec)
            check_range(where, k, v, spec)

        st = c.get("stats", {})
        check_keys(where + ".stats", st, stats_props, stats_required)
        for k, v in st.items():
            check_type(where + ".stats", k, v, stats_props.get(k, {}))
            check_range(where + ".stats", k, v, stats_props.get(k, {}))

        ai = c.get("ai", {})
        check_keys(where + ".ai", ai, ai_props, ai_required)
        for k, v in ai.items():
            check_type(where + ".ai", k, v, ai_props.get(k, {}))

        ult = c.get("ult", {})
        if ult.get("id") and ult_ids and ult["id"] not in ult_ids:
            err(f"{where}.ult.id = 「{ult['id']}」没有对应的绝技实现（ultimates.gd）")

        lines = c.get("lines", {})
        for k, v in lines.items():
            if isinstance(v, list):
                if not all(isinstance(x, str) for x in v):
                    err(f"{where}.lines.{k}: 数组里必须全是字符串")
            elif not isinstance(v, str):
                err(f"{where}.lines.{k}: 必须是字符串或字符串数组")

        if order and cid not in order:
            err(f"武将 {cid} 没写进 order（选将界面不会显示它）")

    for oid in order:
        if oid not in chars:
            err(f"order 里的「{oid}」在 characters 中不存在")
    print(f"  武将: {len(chars)} 名")


# ---------------------------------------------------------------- 平衡参数
def check_balance():
    schema = load(SCHEMA / "balance.schema.json")
    data = load(CFG / "balance.json")
    props = schema.get("properties", {})

    def walk(obj, spec_props, prefix, required=()):
        for k in required:
            if k not in obj:
                err(f"balance.{prefix}{k}: 缺少必填项")
        for k, spec in spec_props.items():
            if k not in obj:
                continue
            v = obj[k]
            if spec.get("type") == "object":
                walk(v, spec.get("properties", {}), prefix + k + ".", spec.get("required", []))
            elif spec.get("type") == "array":
                if not isinstance(v, list):
                    err(f"balance.{prefix}{k}: 应为数组")
                elif "items" in spec and spec["items"].get("type") == "number":
                    if not all(isinstance(x, (int, float)) for x in v):
                        err(f"balance.{prefix}{k}: 数组元素必须是数字")
                    # 难度表必须 4 档
                    if prefix == "ai_difficulty." and len(v) != 4:
                        err(f"balance.{prefix}{k}: 难度表必须是 4 个值（易/中/难/极），现在是 {len(v)}")
            else:
                check_type(f"balance.{prefix}{k}", "", v, spec)
                check_range(f"balance.{prefix}{k}", "", v, spec)

    walk(data, props, "", schema.get("required", []))
    print("  平衡参数: 已校验")


# ---------------------------------------------------------------- 战场
def check_arena():
    schema = load(SCHEMA / "arena.schema.json")
    defs = schema.get("definitions", {})
    data = load(CFG / "arena.json")
    arenas = data.get("arenas", {})
    default = data.get("default", "")
    if default and default not in arenas:
        err(f"arena.default = 「{default}」在 arenas 里不存在")

    for aid, a in arenas.items():
        where = f"arena.{aid}"
        for k in ("name", "map", "ground", "size"):
            if k not in a:
                err(f"{where}: 缺少 {k}")
        size = a.get("size", [])
        if not (isinstance(size, list) and len(size) == 2):
            err(f"{where}.size 必须是 [宽, 高]")
        # 贴图存在性（本地开发时能立刻发现路径写错）
        for key in ("map", "ground"):
            p = a.get(key, "")
            if p.startswith("res://"):
                real = ROOT / "godot" / p.replace("res://", "")
                if not real.exists():
                    err(f"{where}.{key} 指向的文件不存在: {p}")
        presets = a.get("presets", {})
        if not presets:
            warn(f"{where} 没有 presets（时辰光照），会退回纯白染色")
        pprops = defs.get("preset", {}).get("properties", {})
        for pid, pv in presets.items():
            for k, v in pv.items():
                spec = pprops.get(k)
                if spec:
                    check_type(f"{where}.presets.{pid}", k, v, spec)
                    check_range(f"{where}.presets.{pid}", k, v, spec)
    print(f"  战场: {len(arenas)} 个")


# ---------------------------------------------------------------- 成长系统
def check_progression():
    schema = load(SCHEMA / "progression.schema.json")
    props = schema.get("properties", {})
    data = load(CFG / "progression.json")
    if not data:
        return

    def walk(obj, spec, prefix):
        """通用递归：类型 / 多余键 / 必填 / range"""
        t = spec.get("type")
        if t == "object":
            if not isinstance(obj, dict):
                err(f"{prefix or 'progression'}: 应为对象")
                return
            sp = spec.get("properties", {})
            for k in spec.get("required", []):
                if k not in obj:
                    err(f"progression.{prefix}{k}: 缺少必填项")
            for k, v in obj.items():
                if k.startswith("_"):
                    continue
                if sp and k not in sp:
                    if spec.get("additionalProperties") is False:
                        err(f"progression.{prefix}{k}: 多余字段（schema 里没有，八成是拼错了）")
                    else:
                        continue
                if k in sp:
                    walk(v, sp[k], prefix + k + ".")
        elif t == "array":
            if not isinstance(obj, list):
                err(f"progression.{prefix[:-1]}: 应为数组")
                return
            item = spec.get("items", {})
            for i, v in enumerate(obj):
                walk(v, item, f"{prefix}{i}.")
        else:
            if t == "number" and not (isinstance(obj, (int, float)) and not isinstance(obj, bool)):
                err(f"progression.{prefix[:-1]}: 应为数字，实际 {type(obj).__name__}")
            elif t == "integer" and not (isinstance(obj, int) and not isinstance(obj, bool)):
                err(f"progression.{prefix[:-1]}: 应为整数，实际 {type(obj).__name__}")
            elif t == "string" and not isinstance(obj, str):
                err(f"progression.{prefix[:-1]}: 应为字符串")
            elif t == "boolean" and not isinstance(obj, bool):
                err(f"progression.{prefix[:-1]}: 应为布尔值")
            enum = spec.get("enum")
            if enum and obj not in enum:
                err(f"progression.{prefix[:-1]}: {obj!r} 不在允许值 {enum} 中")
            rng = spec.get("range")
            if rng and isinstance(obj, (int, float)) and not isinstance(obj, bool):
                if obj < rng[0] or obj > rng[1]:
                    warn(f"progression.{prefix[:-1]} = {obj} 超出建议区间 {rng}")

    walk(data, {"type": "object", "properties": props, "required": schema.get("required", [])}, "")

    # 业务一致性检查（这些错 schema 查不出来）
    grades = [g.get("id") for g in data.get("score", {}).get("grades", [])]
    mins = [float(g.get("min", 0)) for g in data.get("score", {}).get("grades", [])]
    if mins != sorted(mins):
        err("progression.score.grades: min 必须从低到高排列")
    if len(set(grades)) != len(grades):
        err("progression.score.grades: id 有重复")
    cap = data.get("score", {}).get("timeout_max_grade", "")
    if cap and cap not in grades:
        err(f"progression.score.timeout_max_grade = 「{cap}」不在 grades 里")
    table = data.get("medals", {}).get("by_grade_difficulty", {})
    for gid in grades:
        if gid not in table:
            err(f"progression.medals.by_grade_difficulty: 缺少评价「{gid}」这一行")
        else:
            row = table[gid]
            if not isinstance(row, list) or len(row) != 4:
                err(f"progression.medals.by_grade_difficulty.{gid}: 必须是 4 个值（易/中/难/极）")
    for gid in table:
        if gid not in grades:
            err(f"progression.medals.by_grade_difficulty: 多出评价「{gid}」（grades 里没有）")
    ranks = data.get("rank", {}).get("ranks", [])
    rids = [r.get("id") for r in ranks]
    rmins = [float(r.get("min", 0)) for r in ranks]
    if rmins != sorted(rmins):
        err("progression.rank.ranks: min 必须从低到高排列")
    if len(set(rids)) != len(rids):
        err("progression.rank.ranks: id 有重复")
    if rmins and rmins[0] != 0:
        err("progression.rank.ranks: 最低段位的 min 必须是 0")
    fr = data.get("rank", {}).get("difficulty_gate", {}).get("from_rank", "")
    if fr and fr not in rids:
        err(f"progression.rank.difficulty_gate.from_rank = 「{fr}」不在 ranks 里")
    # 称号条件里的 rank id
    for t in data.get("titles", []):
        rq = t.get("require", {}) or {}
        if rq.get("rank") and rq["rank"] not in rids:
            err(f"progression.titles[{t.get('id')}].require.rank = 「{rq['rank']}」不在 ranks 里")
        if rq.get("grade") and rq["grade"] not in grades:
            err(f"progression.titles[{t.get('id')}].require.grade = 「{rq['grade']}」不在 grades 里")
        if t.get("id") in [x.get("id") for x in data.get("titles", []) if x is not t] and False:
            pass
    tids = [t.get("id") for t in data.get("titles", [])]
    if len(set(tids)) != len(tids):
        err("progression.titles: id 有重复")
    # 解锁武将必须是真实存在的武将
    chars = load(CFG / "characters.json").get("characters", {})
    for cid in data.get("unlocks", {}).get("characters", {}):
        if cid not in chars:
            err(f"progression.unlocks.characters: 武将「{cid}」不存在")
    print(f"  成长系统: {len(grades)} 档评价 / {len(ranks)} 个段位 / {len(tids)} 个称号")


def main():
    strict = "--strict" in sys.argv
    print("=== 配置校验 ===")
    check_characters()
    check_moves()
    check_balance()
    check_arena()
    check_progression()

    print()
    if warnings:
        print(f"⚠️  {len(warnings)} 个警告：")
        for w in warnings:
            print("   - " + w)
    if errors:
        print(f"❌ {len(errors)} 个错误：")
        for e in errors:
            print("   - " + e)
        print("\n校验失败。")
        return 1
    if strict and warnings:
        print("严格模式：有警告即失败。")
        return 1
    print("✅ 配置校验通过。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
