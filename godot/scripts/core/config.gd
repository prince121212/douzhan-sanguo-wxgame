extends Node
## 全局配置加载器（autoload 名：Cfg）
## ---------------------------------------------------------------------------
## 唯一职责：把 godot/config/*.json 读进来，转成 GDScript 类型，对外提供只读访问。
## 业务代码不允许再直接写平衡数值——所有可变数值都从这里取。
##
## 为什么用 JSON 而不是写在 .gd 里：
##   · 策划/AI 改数值不用碰代码，Git diff 一眼看清改了哪条；
##   · 换主题/加武将只改配置；
##   · Schema 文件（config/schema/）约束结构，防止 AI 多轮对话后把格式改乱。
##
## 注意 Godot 的 JSON 坑（都在这一个文件里处理掉）：
##   1. 解析出来所有数字都是 float，int 字段要显式 int()；
##   2. 没有 Color 类型，颜色统一存 "#RRGGBB" / "#RRGGBBAA"；
##   3. JSON 不支持注释，说明写在 schema 的 description 里。
## ---------------------------------------------------------------------------

const DIR := "res://config/"

var balance: Dictionary = {}
var characters: Dictionary = {}      # id -> def（已转好 Color/int）
var character_order: Array = []
var rivalry: Dictionary = {}
var moves: Dictionary = {}           # "weapon|stand"/"weapon|mounted" -> 稀疏招式表
var move_defaults: Dictionary = {}
var arenas: Dictionary = {}
var arena_default := "hulaoguan"

var _loaded := false


func _ready() -> void:
	reload()


## 重新读全部配置（游戏里按 F9 可热重载，调平衡不用重启）
func reload() -> void:
	var t0 := Time.get_ticks_msec()
	balance = _read("balance.json")
	_load_characters()
	_load_moves()
	_load_arenas()
	_loaded = true
	print("Cfg: 配置已加载（%d 武将 / %d 招式组 / %d 战场 / %d ms）" % [
		characters.size(), moves.size(), arenas.size(), Time.get_ticks_msec() - t0])


# ---------------------------------------------------------------- 读取工具

func _read(rel: String) -> Dictionary:
	var path := DIR + rel
	if not FileAccess.file_exists(path):
		push_error("Cfg: 缺少配置文件 " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed == null:
		push_error("Cfg: %s 解析失败（JSON 语法错误？）" % path)
		return {}
	if parsed is not Dictionary:
		push_error("Cfg: %s 顶层必须是对象" % path)
		return {}
	return parsed


## "#RRGGBB" / "#RRGGBBAA" -> Color
func to_color(v) -> Color:
	if v is Color:
		return v
	if v is String and v.begins_with("#"):
		return Color.from_string(v, Color.MAGENTA)
	return Color.MAGENTA   # 明显错误色，一眼能看出配置写错


# ---------------------------------------------------------------- 武将

func _load_characters() -> void:
	var raw := _read("characters.json")
	characters = {}
	character_order = raw.get("order", [])
	rivalry = raw.get("rivalry", {})
	var src: Dictionary = raw.get("characters", {})
	for id in src:
		characters[id] = _convert_character(src[id])
	# order 里漏写的武将补到末尾（防止新增武将忘了登记顺序时「看不见」）
	for id in characters:
		if not (id in character_order):
			character_order.append(id)


func _convert_character(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	out["color"] = to_color(d.get("color", "#FF00FF"))
	if d.has("color2"):
		out["color2"] = to_color(d["color2"])
	if d.has("stats"):
		for k in d["stats"]:
			out["stats"][k] = int(d["stats"][k])
	out["hp"] = int(d.get("hp", 1000))
	out["size"] = float(d.get("size", 1.0))
	if d.has("mount_dmg"):
		out["mount_dmg"] = float(d["mount_dmg"])
	return out


# ---------------------------------------------------------------- 招式

func _load_moves() -> void:
	move_defaults = _read("moves/_defaults.json").get("defaults", {})
	moves = {}
	var dir := DirAccess.open(DIR + "moves")
	if dir == null:
		push_error("Cfg: 找不到 config/moves 目录")
		return
	for fname in dir.get_files():
		if not fname.ends_with(".json") or fname.begins_with("_"):
			continue
		var raw := _read("moves/" + fname)
		var weapon: String = raw.get("weapon", fname.get_basename())
		for stance in ["stand", "mounted"]:
			if raw.has(stance):
				moves[weapon + "|" + stance] = raw[stance]


## 取某兵器某姿态的稀疏招式表（未叠加 DEFAULTS）
func moveset(weapon: String, mounted: bool) -> Dictionary:
	var key := weapon + ("|mounted" if mounted else "|stand")
	return moves.get(key, moves.get("spear|" + ("mounted" if mounted else "stand"), {}))


# ---------------------------------------------------------------- 战场

func _load_arenas() -> void:
	var raw := _read("arena.json")
	arena_default = raw.get("default", "hulaoguan")
	arenas = {}
	var src: Dictionary = raw.get("arenas", {})
	for id in src:
		var a: Dictionary = src[id].duplicate(true)
		var presets := {}
		for pid in a.get("presets", {}):
			presets[pid] = _convert_preset(a["presets"][pid])
		a["presets"] = presets
		arenas[id] = a


func _convert_preset(p: Dictionary) -> Dictionary:
	var out := p.duplicate(true)
	for k in ["map", "actor", "haze", "grade", "lift", "ray", "dust"]:
		if out.has(k):
			out[k] = to_color(out[k])
	for k in ["map_sat", "map_bright", "vignette", "sat", "contrast", "ray_a"]:
		if out.has(k):
			out[k] = float(out[k])
	if out.has("motes"):
		out["motes"] = int(out["motes"])
	return out


func arena(id := "") -> Dictionary:
	var key := id if id != "" else arena_default
	return arenas.get(key, arenas.get(arena_default, {}))


# ---------------------------------------------------------------- 便捷取值

## 平衡参数：Cfg.bal("round.time_limit_duel", 180.0)
func bal(path: String, default_value = null):
	var cur = balance
	for part in path.split("."):
		if cur is Dictionary and cur.has(part):
			cur = cur[part]
		else:
			return default_value
	return cur


func bal_float(path: String, default_value := 0.0) -> float:
	return float(bal(path, default_value))


func bal_int(path: String, default_value := 0) -> int:
	return int(bal(path, default_value))
