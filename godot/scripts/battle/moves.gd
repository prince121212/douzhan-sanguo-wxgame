class_name Moves
extends RefCounted
## 招式表（薄壳）：数据来自 config/moves/<weapon>.json，默认值来自 _defaults.json。
##
## 设计：配置文件只写「与默认值不同」的字段（稀疏表）。
## 好处：新增兵器只需加一个 json；调整某招只需写它真正关心的几项；
##      改默认值能一次影响所有招式（例如整体加快收招）。
##
## 注意：拼错字段名会被静默忽略（因为这里是字典叠加）。
##       所以改完招式务必跑 `bash _tools/check_config.sh`，它会揪出多余键。

## 默认值（运行时从 Cfg 取，保留此属性兼容旧调用）
static var DEFAULTS: Dictionary:
	get:
		return Cfg.move_defaults if Cfg and not Cfg.move_defaults.is_empty() else _fallback_defaults()

static func _fallback_defaults() -> Dictionary:
	# 仅在 Cfg 尚未就绪时兜底（正常不会走到）
	return {
		"kind": "melee", "startup": 0.14, "active": 0.10, "recovery": 0.24,
		"dmg": 40.0, "hits": 1, "reach": 150.0, "back": 20.0, "depth": 40.0, "height": 70.0,
		"lunge": 20.0, "lunge_startup": 0.0, "hitstun": 0.30, "kb": 150.0, "launch": 0.0,
		"guard_dmg": 10.0, "chip": 0.08, "breaks_guard": false, "armor": false, "clash": 1,
		"next": "", "heavy_next": "", "cancel": 0.14, "vfx": "thrust", "arc": [-30.0, 30.0],
		"sfx_swing": "slash", "sfx_hit": "hit_light", "shake": 0.12, "hitstop": 0.055, "zoom_kick": 0.0,
		"charge": {}, "rage": 1.0, "tilt_startup": -7.0, "tilt_active": 5.0, "air": false,
		"projectile": {}, "label": "", "pose_startup": "windup", "pose_active": "attack",
		"run": false, "ground_ring": false,
	}


static func _m(d: Dictionary) -> Dictionary:
	var out := DEFAULTS.duplicate(true)
	for k in d:
		out[k] = d[k]
	return out


## 取一个武将在某姿态下的完整招式表（稀疏表 + DEFAULTS）
static func moveset(weapon: String, mounted: bool) -> Dictionary:
	var raw: Dictionary = Cfg.moveset(weapon, mounted)
	var out := {}
	for k in raw:
		var mv: Dictionary = _m(raw[k])
		mv["id"] = k
		out[k] = mv
	return out


## 原始稀疏表（未叠加 DEFAULTS）。给校验器和导出脚本用。
static func raw_set(weapon: String, mounted: bool) -> Dictionary:
	return Cfg.moveset(weapon, mounted)
