class_name Moves
extends RefCounted
## 招式数据。每把兵器一套步战招式、一套马战招式。
## 时间单位秒，距离单位世界坐标（地图像素）。伤害为基础值，再乘武力/统率换算。

const DEFAULTS := {
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


## 取一个武将在某姿态下的招式表
static func moveset(weapon: String, mounted: bool) -> Dictionary:
	var set_dict: Dictionary
	if mounted:
		set_dict = _mounted(weapon)
	else:
		match weapon:
			"spear": set_dict = _spear()
			"glaive": set_dict = _glaive()
			"snake": set_dict = _snake()
			"cleaver": set_dict = _cleaver()
			"dual": set_dict = _dual()
			"bow": set_dict = _bow()
			"halberd": set_dict = _halberd()
			_: set_dict = _spear()
	var out := {}
	for k in set_dict:
		var mv: Dictionary = _m(set_dict[k])
		mv["id"] = k
		out[k] = mv
	return out


# ---------------------------------------------------------------- 步战

static func _spear() -> Dictionary:
	return {
		"l1": {"label": "刺", "startup": 0.11, "active": 0.09, "recovery": 0.20, "dmg": 34.0,
			"reach": 150.0, "depth": 34.0, "lunge": 26.0, "next": "l2", "heavy_next": "launch"},
		"l2": {"label": "连刺", "startup": 0.10, "active": 0.09, "recovery": 0.22, "dmg": 38.0,
			"reach": 155.0, "depth": 34.0, "lunge": 30.0, "next": "l3", "heavy_next": "launch"},
		"l3": {"label": "突刺", "startup": 0.17, "active": 0.12, "recovery": 0.36, "dmg": 60.0,
			"reach": 190.0, "depth": 36.0, "lunge": 80.0, "kb": 380.0, "hitstun": 0.55,
			"shake": 0.26, "hitstop": 0.09, "sfx_hit": "hit_heavy", "zoom_kick": 0.04, "tilt_active": 9.0},
		"launch": {"label": "挑枪", "startup": 0.20, "active": 0.12, "recovery": 0.40, "dmg": 52.0,
			"reach": 150.0, "depth": 38.0, "lunge": 40.0, "launch": 620.0, "kb": 160.0,
			"vfx": "slash_up", "arc": [60.0, -80.0], "shake": 0.28, "hitstop": 0.09, "sfx_hit": "hit_heavy",
			"tilt_startup": 8.0, "tilt_active": -14.0, "guard_dmg": 25.0, "clash": 2},
		"heavy": {"label": "破阵枪", "startup": 0.34, "active": 0.13, "recovery": 0.46, "dmg": 82.0,
			"reach": 205.0, "depth": 38.0, "lunge": 120.0, "kb": 460.0, "hitstun": 0.6,
			"guard_dmg": 45.0, "breaks_guard": true, "clash": 2, "shake": 0.34, "hitstop": 0.11,
			"sfx_hit": "hit_heavy", "zoom_kick": 0.06, "tilt_startup": -12.0, "tilt_active": 10.0,
			"charge": {"max": 0.75, "dmg_mult": 1.6, "reach_add": 40.0, "launch_at": 0.7, "launch": 480.0}},
		"air": {"label": "飞身刺", "startup": 0.08, "active": 0.22, "recovery": 0.20, "dmg": 50.0,
			"reach": 140.0, "depth": 40.0, "height": 160.0, "lunge": 60.0, "air": true, "kb": 280.0,
			"guard_dmg": 30.0, "tilt_active": 25.0, "shake": 0.2, "sfx_hit": "hit_heavy"},
		"run": {"label": "冲刺", "startup": 0.08, "active": 0.14, "recovery": 0.34, "dmg": 56.0,
			"reach": 170.0, "depth": 38.0, "lunge": 140.0, "kb": 420.0, "run": true, "hitstun": 0.5,
			"guard_dmg": 30.0, "shake": 0.24, "sfx_hit": "hit_heavy", "tilt_active": 12.0, "clash": 2},
	}


static func _glaive() -> Dictionary:
	return {
		"l1": {"label": "劈", "startup": 0.14, "active": 0.12, "recovery": 0.25, "dmg": 47.0,
			"reach": 150.0, "depth": 54.0, "lunge": 22.0, "vfx": "slash", "arc": [-70.0, 40.0],
			"next": "l2", "heavy_next": "launch", "tilt_startup": -10.0, "tilt_active": 8.0},
		"l2": {"label": "回斩", "startup": 0.14, "active": 0.12, "recovery": 0.28, "dmg": 52.0,
			"reach": 150.0, "depth": 54.0, "lunge": 22.0, "vfx": "slash", "arc": [50.0, -60.0],
			"next": "l3", "heavy_next": "launch", "tilt_startup": 6.0, "tilt_active": -8.0},
		"l3": {"label": "斩月", "startup": 0.24, "active": 0.14, "recovery": 0.44, "dmg": 82.0,
			"reach": 170.0, "depth": 58.0, "lunge": 50.0, "vfx": "slash_down", "arc": [-110.0, 50.0],
			"kb": 360.0, "launch": 360.0, "shake": 0.34, "hitstop": 0.11, "sfx_hit": "hit_heavy",
			"zoom_kick": 0.05, "tilt_startup": -16.0, "tilt_active": 14.0, "clash": 2},
		"launch": {"label": "撩刀", "startup": 0.22, "active": 0.13, "recovery": 0.42, "dmg": 58.0,
			"reach": 150.0, "depth": 56.0, "lunge": 30.0, "vfx": "slash_up", "arc": [70.0, -90.0],
			"launch": 600.0, "kb": 160.0, "shake": 0.3, "hitstop": 0.1, "sfx_hit": "hit_heavy",
			"tilt_startup": 10.0, "tilt_active": -16.0, "clash": 2, "guard_dmg": 28.0},
		"heavy": {"label": "拖刀斩", "startup": 0.40, "active": 0.15, "recovery": 0.50, "dmg": 98.0,
			"reach": 185.0, "depth": 62.0, "lunge": 90.0, "vfx": "slash", "arc": [-120.0, 70.0],
			"kb": 480.0, "hitstun": 0.65, "guard_dmg": 55.0, "breaks_guard": true, "clash": 2,
			"shake": 0.4, "hitstop": 0.12, "sfx_hit": "hit_heavy", "zoom_kick": 0.07,
			"tilt_startup": -18.0, "tilt_active": 12.0,
			"charge": {"max": 0.8, "dmg_mult": 1.65, "reach_add": 30.0, "launch_at": 0.7, "launch": 420.0}},
		"air": {"label": "跃斩", "startup": 0.10, "active": 0.22, "recovery": 0.24, "dmg": 60.0,
			"reach": 150.0, "depth": 56.0, "height": 170.0, "lunge": 40.0, "air": true, "kb": 300.0,
			"vfx": "slash_down", "arc": [-120.0, 60.0], "guard_dmg": 40.0, "tilt_active": 22.0,
			"shake": 0.26, "sfx_hit": "hit_heavy"},
		"run": {"label": "奔袭斩", "startup": 0.10, "active": 0.15, "recovery": 0.38, "dmg": 64.0,
			"reach": 165.0, "depth": 56.0, "lunge": 120.0, "kb": 420.0, "run": true, "vfx": "slash",
			"arc": [-80.0, 50.0], "guard_dmg": 34.0, "shake": 0.26, "sfx_hit": "hit_heavy", "clash": 2},
	}


static func _snake() -> Dictionary:
	return {
		"l1": {"label": "蛇矛刺", "startup": 0.13, "active": 0.10, "recovery": 0.24, "dmg": 42.0,
			"reach": 162.0, "depth": 36.0, "lunge": 30.0, "kb": 190.0, "next": "l2", "heavy_next": "launch"},
		"l2": {"label": "回马刺", "startup": 0.12, "active": 0.10, "recovery": 0.26, "dmg": 46.0,
			"reach": 165.0, "depth": 36.0, "lunge": 34.0, "kb": 200.0, "next": "l3", "heavy_next": "launch"},
		"l3": {"label": "蛇矛三连", "startup": 0.16, "active": 0.26, "recovery": 0.40, "dmg": 28.0, "hits": 3,
			"reach": 178.0, "depth": 38.0, "lunge": 60.0, "kb": 300.0, "hitstun": 0.45,
			"shake": 0.22, "hitstop": 0.05, "sfx_hit": "hit_heavy", "tilt_active": 7.0},
		"launch": {"label": "挑矛", "startup": 0.22, "active": 0.12, "recovery": 0.42, "dmg": 56.0,
			"reach": 160.0, "depth": 40.0, "lunge": 40.0, "launch": 640.0, "kb": 180.0, "vfx": "slash_up",
			"arc": [60.0, -85.0], "shake": 0.3, "hitstop": 0.1, "sfx_hit": "hit_heavy", "clash": 2,
			"tilt_startup": 9.0, "tilt_active": -15.0, "guard_dmg": 28.0},
		"heavy": {"label": "怒矛", "startup": 0.38, "active": 0.14, "recovery": 0.48, "dmg": 96.0,
			"reach": 215.0, "depth": 40.0, "lunge": 120.0, "kb": 560.0, "hitstun": 0.65,
			"guard_dmg": 55.0, "breaks_guard": true, "clash": 2, "shake": 0.42, "hitstop": 0.12,
			"sfx_hit": "hit_heavy", "zoom_kick": 0.07, "tilt_startup": -13.0, "tilt_active": 11.0,
			"charge": {"max": 0.8, "dmg_mult": 1.6, "reach_add": 40.0, "launch_at": 0.7, "launch": 500.0}},
		"air": {"label": "跃矛", "startup": 0.09, "active": 0.22, "recovery": 0.22, "dmg": 56.0,
			"reach": 150.0, "depth": 40.0, "height": 160.0, "lunge": 60.0, "air": true, "kb": 320.0,
			"guard_dmg": 34.0, "tilt_active": 25.0, "shake": 0.24, "sfx_hit": "hit_heavy"},
		"run": {"label": "猛冲", "startup": 0.09, "active": 0.14, "recovery": 0.36, "dmg": 62.0,
			"reach": 180.0, "depth": 40.0, "lunge": 150.0, "kb": 480.0, "run": true, "hitstun": 0.5,
			"guard_dmg": 36.0, "shake": 0.28, "sfx_hit": "hit_heavy", "tilt_active": 12.0, "clash": 2},
	}


static func _cleaver() -> Dictionary:
	return {
		"l1": {"label": "劈刀", "startup": 0.16, "active": 0.12, "recovery": 0.28, "dmg": 56.0,
			"reach": 122.0, "depth": 56.0, "lunge": 26.0, "kb": 220.0, "vfx": "slash", "arc": [-70.0, 40.0],
			"next": "l2", "heavy_next": "launch", "tilt_startup": -10.0, "tilt_active": 9.0,
			"sfx_hit": "hit_heavy"},
		"l2": {"label": "横扫", "startup": 0.16, "active": 0.12, "recovery": 0.30, "dmg": 60.0,
			"reach": 125.0, "depth": 58.0, "lunge": 26.0, "kb": 240.0, "vfx": "slash", "arc": [40.0, -60.0],
			"next": "l3", "heavy_next": "launch", "tilt_startup": 6.0, "tilt_active": -9.0, "sfx_hit": "hit_heavy"},
		"l3": {"label": "开山", "startup": 0.28, "active": 0.14, "recovery": 0.48, "dmg": 98.0,
			"reach": 140.0, "depth": 64.0, "lunge": 40.0, "kb": 380.0, "launch": 300.0, "vfx": "slash_down",
			"arc": [-120.0, 60.0], "shake": 0.45, "hitstop": 0.13, "sfx_hit": "hit_heavy", "zoom_kick": 0.06,
			"tilt_startup": -18.0, "tilt_active": 16.0, "ground_ring": true, "clash": 2, "armor": true},
		"launch": {"label": "挑刀", "startup": 0.24, "active": 0.13, "recovery": 0.44, "dmg": 66.0,
			"reach": 124.0, "depth": 58.0, "lunge": 30.0, "launch": 580.0, "kb": 160.0, "vfx": "slash_up",
			"arc": [70.0, -90.0], "shake": 0.32, "hitstop": 0.11, "sfx_hit": "hit_heavy", "clash": 2,
			"tilt_startup": 10.0, "tilt_active": -16.0, "guard_dmg": 32.0},
		"heavy": {"label": "虎劈", "startup": 0.44, "active": 0.15, "recovery": 0.52, "dmg": 112.0,
			"reach": 140.0, "depth": 66.0, "lunge": 60.0, "kb": 500.0, "hitstun": 0.7, "vfx": "slash_down",
			"arc": [-130.0, 60.0], "guard_dmg": 65.0, "breaks_guard": true, "armor": true, "clash": 3,
			"shake": 0.5, "hitstop": 0.14, "sfx_hit": "hit_heavy", "zoom_kick": 0.08, "ground_ring": true,
			"tilt_startup": -20.0, "tilt_active": 16.0,
			"charge": {"max": 0.8, "dmg_mult": 1.6, "reach_add": 20.0, "launch_at": 0.7, "launch": 420.0}},
		"air": {"label": "泰山压顶", "startup": 0.10, "active": 0.24, "recovery": 0.30, "dmg": 70.0,
			"reach": 130.0, "depth": 60.0, "height": 170.0, "lunge": 30.0, "air": true, "kb": 340.0,
			"vfx": "slash_down", "arc": [-130.0, 60.0], "guard_dmg": 45.0, "tilt_active": 22.0,
			"shake": 0.34, "sfx_hit": "hit_heavy", "ground_ring": true},
		"run": {"label": "蛮冲", "startup": 0.10, "active": 0.16, "recovery": 0.40, "dmg": 66.0,
			"reach": 130.0, "depth": 58.0, "lunge": 120.0, "kb": 460.0, "run": true, "vfx": "slash",
			"arc": [-80.0, 50.0], "guard_dmg": 40.0, "shake": 0.3, "sfx_hit": "hit_heavy", "armor": true, "clash": 2},
	}


static func _dual() -> Dictionary:
	return {
		"l1": {"label": "双戟", "startup": 0.12, "active": 0.14, "recovery": 0.22, "dmg": 22.0, "hits": 2,
			"reach": 132.0, "depth": 46.0, "lunge": 24.0, "kb": 150.0, "vfx": "slash", "arc": [-60.0, 40.0],
			"next": "l2", "heavy_next": "launch", "tilt_startup": -8.0, "tilt_active": 7.0},
		"l2": {"label": "交戟", "startup": 0.12, "active": 0.14, "recovery": 0.24, "dmg": 24.0, "hits": 2,
			"reach": 134.0, "depth": 46.0, "lunge": 26.0, "kb": 160.0, "vfx": "slash", "arc": [50.0, -50.0],
			"next": "l3", "heavy_next": "launch", "tilt_startup": 6.0, "tilt_active": -7.0},
		"l3": {"label": "旋戟", "startup": 0.18, "active": 0.26, "recovery": 0.40, "dmg": 25.0, "hits": 3,
			"reach": 140.0, "depth": 56.0, "back": 60.0, "lunge": 50.0, "kb": 330.0, "hitstun": 0.45,
			"vfx": "spin", "shake": 0.26, "hitstop": 0.05, "sfx_hit": "hit_heavy"},
		"launch": {"label": "挑戟", "startup": 0.20, "active": 0.13, "recovery": 0.40, "dmg": 54.0,
			"reach": 132.0, "depth": 48.0, "lunge": 30.0, "launch": 600.0, "kb": 160.0, "vfx": "slash_up",
			"arc": [60.0, -85.0], "shake": 0.3, "hitstop": 0.1, "sfx_hit": "hit_heavy", "clash": 2,
			"tilt_startup": 9.0, "tilt_active": -15.0, "guard_dmg": 26.0},
		"heavy": {"label": "铁戟劈", "startup": 0.38, "active": 0.15, "recovery": 0.48, "dmg": 96.0,
			"reach": 150.0, "depth": 56.0, "lunge": 80.0, "kb": 480.0, "hitstun": 0.65, "vfx": "slash_down",
			"arc": [-120.0, 60.0], "guard_dmg": 55.0, "breaks_guard": true, "clash": 2, "armor": true,
			"shake": 0.42, "hitstop": 0.12, "sfx_hit": "hit_heavy", "zoom_kick": 0.07,
			"tilt_startup": -16.0, "tilt_active": 14.0,
			"charge": {"max": 0.8, "dmg_mult": 1.6, "reach_add": 25.0, "launch_at": 0.7, "launch": 440.0}},
		"air": {"label": "飞戟", "startup": 0.09, "active": 0.22, "recovery": 0.22, "dmg": 28.0, "hits": 2,
			"reach": 130.0, "depth": 50.0, "height": 160.0, "lunge": 50.0, "air": true, "kb": 300.0,
			"vfx": "slash_down", "arc": [-110.0, 60.0], "guard_dmg": 32.0, "tilt_active": 20.0, "shake": 0.22,
			"sfx_hit": "hit_heavy"},
		"run": {"label": "恶来冲", "startup": 0.09, "active": 0.16, "recovery": 0.36, "dmg": 30.0, "hits": 2,
			"reach": 140.0, "depth": 50.0, "lunge": 130.0, "kb": 420.0, "run": true, "vfx": "spin",
			"guard_dmg": 34.0, "shake": 0.26, "sfx_hit": "hit_heavy", "clash": 2},
	}


static func _bow() -> Dictionary:
	return {
		# 远处轻击是射箭，近身轻击是弓击（由 fighter 按距离选择 l1 / bash）
		"l1": {"label": "连珠箭", "kind": "projectile", "startup": 0.15, "active": 0.06, "recovery": 0.24,
			"dmg": 39.0, "next": "l2", "heavy_next": "", "vfx": "none", "sfx_swing": "bow",
			"projectile": {"speed": 1500.0, "life": 1.1, "pierce": false, "size": 1.0, "kb": 140.0, "hitstun": 0.26},
			"tilt_startup": -4.0, "tilt_active": 3.0, "cancel": 0.2},
		"l2": {"label": "连珠箭", "kind": "projectile", "startup": 0.12, "active": 0.06, "recovery": 0.26,
			"dmg": 39.0, "next": "l3", "vfx": "none", "sfx_swing": "bow",
			"projectile": {"speed": 1550.0, "life": 1.1, "pierce": false, "size": 1.0, "kb": 140.0, "hitstun": 0.26},
			"tilt_startup": -4.0, "tilt_active": 3.0, "cancel": 0.2},
		"l3": {"label": "三连珠", "kind": "projectile", "startup": 0.14, "active": 0.06, "recovery": 0.36,
			"dmg": 50.0, "vfx": "none", "sfx_swing": "bow",
			"projectile": {"speed": 1700.0, "life": 1.1, "pierce": false, "size": 1.15, "kb": 300.0, "hitstun": 0.45},
			"tilt_startup": -5.0, "tilt_active": 4.0},
		"bash": {"label": "弓击", "startup": 0.11, "active": 0.10, "recovery": 0.22, "dmg": 40.0,
			"reach": 118.0, "depth": 46.0, "lunge": 24.0, "kb": 400.0, "hitstun": 0.42, "vfx": "slash",
			"arc": [-50.0, 40.0], "next": "", "heavy_next": "launch", "sfx_hit": "hit_light"},
		"launch": {"label": "踢腿", "startup": 0.16, "active": 0.12, "recovery": 0.36, "dmg": 44.0,
			"reach": 110.0, "depth": 44.0, "lunge": 30.0, "launch": 520.0, "kb": 260.0, "vfx": "slash_up",
			"arc": [60.0, -80.0], "shake": 0.24, "hitstop": 0.09, "sfx_hit": "hit_heavy", "clash": 1},
		"heavy": {"label": "满弓", "kind": "projectile", "startup": 0.34, "active": 0.08, "recovery": 0.44,
			"dmg": 84.0, "vfx": "none", "sfx_swing": "bow", "clash": 0, "tilt_startup": -8.0, "tilt_active": 6.0,
			"projectile": {"speed": 2300.0, "life": 1.0, "pierce": true, "size": 1.5, "kb": 420.0, "hitstun": 0.6, "gold": true},
			"guard_dmg": 40.0,
			"charge": {"max": 0.9, "dmg_mult": 1.9, "reach_add": 0.0, "launch_at": 0.75, "launch": 420.0}},
		"air": {"label": "跃射", "kind": "projectile", "startup": 0.10, "active": 0.06, "recovery": 0.20,
			"dmg": 36.0, "air": true, "vfx": "none", "sfx_swing": "bow",
			"projectile": {"speed": 1600.0, "life": 1.0, "pierce": false, "size": 1.1, "kb": 200.0, "hitstun": 0.35, "dive": 0.35}},
		"run": {"label": "回身射", "kind": "projectile", "startup": 0.10, "active": 0.06, "recovery": 0.30,
			"dmg": 44.0, "run": true, "vfx": "none", "sfx_swing": "bow",
			"projectile": {"speed": 1800.0, "life": 1.1, "pierce": false, "size": 1.2, "kb": 320.0, "hitstun": 0.45}},
	}


static func _halberd() -> Dictionary:
	return {
		"l1": {"label": "戟刺", "startup": 0.11, "active": 0.10, "recovery": 0.21, "dmg": 44.0,
			"reach": 168.0, "depth": 40.0, "lunge": 30.0, "kb": 170.0, "next": "l2", "heavy_next": "launch"},
		"l2": {"label": "横扫", "startup": 0.13, "active": 0.13, "recovery": 0.25, "dmg": 50.0,
			"reach": 165.0, "depth": 62.0, "lunge": 26.0, "kb": 200.0, "vfx": "slash", "arc": [-70.0, 50.0],
			"next": "l3", "heavy_next": "launch", "tilt_startup": -9.0, "tilt_active": 9.0},
		"l3": {"label": "画戟挑", "startup": 0.20, "active": 0.13, "recovery": 0.40, "dmg": 76.0,
			"reach": 175.0, "depth": 46.0, "lunge": 60.0, "launch": 560.0, "kb": 260.0, "vfx": "slash_up",
			"arc": [70.0, -95.0], "shake": 0.34, "hitstop": 0.11, "sfx_hit": "hit_heavy", "zoom_kick": 0.05,
			"tilt_startup": 10.0, "tilt_active": -16.0, "clash": 2},
		"launch": {"label": "戟挑", "startup": 0.19, "active": 0.12, "recovery": 0.40, "dmg": 60.0,
			"reach": 165.0, "depth": 44.0, "lunge": 40.0, "launch": 620.0, "kb": 180.0, "vfx": "slash_up",
			"arc": [60.0, -85.0], "shake": 0.3, "hitstop": 0.1, "sfx_hit": "hit_heavy", "clash": 2,
			"tilt_startup": 9.0, "tilt_active": -15.0, "guard_dmg": 30.0},
		"heavy": {"label": "霸王扫", "startup": 0.36, "active": 0.16, "recovery": 0.48, "dmg": 108.0,
			"reach": 195.0, "depth": 66.0, "lunge": 80.0, "kb": 520.0, "hitstun": 0.65, "vfx": "slash",
			"arc": [-130.0, 70.0], "guard_dmg": 60.0, "breaks_guard": true, "armor": true, "clash": 3,
			"shake": 0.46, "hitstop": 0.13, "sfx_hit": "hit_heavy", "zoom_kick": 0.08,
			"tilt_startup": -18.0, "tilt_active": 13.0,
			"charge": {"max": 0.75, "dmg_mult": 1.6, "reach_add": 30.0, "launch_at": 0.7, "launch": 460.0}},
		"air": {"label": "飞将劈", "startup": 0.09, "active": 0.22, "recovery": 0.22, "dmg": 62.0,
			"reach": 160.0, "depth": 56.0, "height": 170.0, "lunge": 50.0, "air": true, "kb": 340.0,
			"vfx": "slash_down", "arc": [-120.0, 60.0], "guard_dmg": 40.0, "tilt_active": 22.0, "shake": 0.28,
			"sfx_hit": "hit_heavy"},
		"run": {"label": "飞将冲", "startup": 0.08, "active": 0.15, "recovery": 0.34, "dmg": 64.0,
			"reach": 185.0, "depth": 44.0, "lunge": 150.0, "kb": 480.0, "run": true, "hitstun": 0.5,
			"guard_dmg": 36.0, "shake": 0.28, "sfx_hit": "hit_heavy", "tilt_active": 12.0, "clash": 2},
	}


# ---------------------------------------------------------------- 马战

static func _mounted(weapon: String) -> Dictionary:
	var reach_add := 0.0
	var slash := false
	var dmg_mult := 1.0
	match weapon:
		"spear":
			reach_add = 10.0
		"snake":
			reach_add = 18.0
			dmg_mult = 1.08
		"glaive":
			slash = true
			dmg_mult = 1.1
		"cleaver":
			slash = true
			reach_add = -25.0
			dmg_mult = 1.18
		"dual":
			slash = true
			reach_add = -15.0
		"halberd":
			reach_add = 15.0
			dmg_mult = 1.1
	if weapon == "bow":
		return {
			"l1": {"label": "骑射", "kind": "projectile", "startup": 0.15, "active": 0.06, "recovery": 0.26,
				"dmg": 38.0, "next": "l2", "vfx": "none", "sfx_swing": "bow", "cancel": 0.2,
				"projectile": {"speed": 1550.0, "life": 1.1, "pierce": false, "size": 1.0, "kb": 150.0, "hitstun": 0.28},
				"tilt_startup": -3.0, "tilt_active": 2.0},
			"l2": {"label": "连射", "kind": "projectile", "startup": 0.13, "active": 0.06, "recovery": 0.32,
				"dmg": 42.0, "vfx": "none", "sfx_swing": "bow",
				"projectile": {"speed": 1600.0, "life": 1.1, "pierce": false, "size": 1.05, "kb": 220.0, "hitstun": 0.34},
				"tilt_startup": -3.0, "tilt_active": 2.0},
			"bash": {"label": "马上弓击", "startup": 0.14, "active": 0.11, "recovery": 0.28, "dmg": 40.0,
				"reach": 150.0, "depth": 50.0, "lunge": 20.0, "kb": 300.0, "vfx": "slash", "arc": [-50.0, 40.0]},
			"heavy": {"label": "满弓", "kind": "projectile", "startup": 0.36, "active": 0.08, "recovery": 0.44,
				"dmg": 88.0, "vfx": "none", "sfx_swing": "bow", "clash": 0, "guard_dmg": 40.0,
				"projectile": {"speed": 2300.0, "life": 1.0, "pierce": true, "size": 1.5, "kb": 420.0, "hitstun": 0.6, "gold": true},
				"charge": {"max": 0.9, "dmg_mult": 1.9, "reach_add": 0.0, "launch_at": 0.75, "launch": 380.0}},
			"charge": {"label": "驰射", "kind": "projectile", "startup": 0.10, "active": 0.06, "recovery": 0.30,
				"dmg": 50.0, "run": true, "vfx": "none", "sfx_swing": "bow",
				"projectile": {"speed": 1900.0, "life": 1.1, "pierce": false, "size": 1.3, "kb": 360.0, "hitstun": 0.5}},
		}
	var v1 := "slash" if slash else "thrust"
	return {
		"l1": {"label": "马上" + ("斩" if slash else "刺"), "startup": 0.16, "active": 0.12, "recovery": 0.30,
			"dmg": 50.0 * dmg_mult, "reach": 190.0 + reach_add, "depth": 48.0, "lunge": 16.0, "kb": 220.0,
			"vfx": v1, "arc": [-70.0, 45.0], "next": "l2", "heavy_next": "", "tilt_startup": -6.0, "tilt_active": 5.0},
		"l2": {"label": "回马" + ("刀" if slash else "枪"), "startup": 0.16, "active": 0.12, "recovery": 0.36,
			"dmg": 58.0 * dmg_mult, "reach": 195.0 + reach_add, "depth": 50.0, "lunge": 16.0, "kb": 300.0,
			"hitstun": 0.45, "vfx": v1, "arc": [50.0, -60.0], "tilt_startup": 6.0, "tilt_active": -6.0,
			"shake": 0.2, "sfx_hit": "hit_heavy"},
		"heavy": {"label": "马上重击", "startup": 0.38, "active": 0.15, "recovery": 0.50, "dmg": 92.0 * dmg_mult,
			"reach": 205.0 + reach_add, "depth": 56.0, "lunge": 30.0, "kb": 460.0, "hitstun": 0.6,
			"vfx": "slash" if slash else "thrust", "arc": [-120.0, 60.0], "guard_dmg": 55.0, "breaks_guard": true,
			"clash": 2, "shake": 0.4, "hitstop": 0.12, "sfx_hit": "hit_heavy", "zoom_kick": 0.06,
			"tilt_startup": -12.0, "tilt_active": 10.0,
			"charge": {"max": 0.8, "dmg_mult": 1.55, "reach_add": 25.0, "launch_at": 0.7, "launch": 380.0}},
		# 纵马冲锋时出手：伤害随马速增长
		"charge": {"label": "冲锋", "startup": 0.10, "active": 0.20, "recovery": 0.46, "dmg": 74.0 * dmg_mult,
			"reach": 210.0 + reach_add, "depth": 52.0, "lunge": 0.0, "kb": 520.0, "launch": 380.0, "run": true,
			"vfx": v1, "arc": [-90.0, 50.0], "guard_dmg": 60.0, "breaks_guard": true, "clash": 3, "armor": true,
			"shake": 0.45, "hitstop": 0.13, "sfx_hit": "hit_heavy", "zoom_kick": 0.07, "tilt_active": 8.0},
	}
