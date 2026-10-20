extends Node2D
## 虎牢关战场：底图、两侧助威的兵卒、帅旗、飞尘、光束、时辰光照。

const MAP_PATH := "res://assets/bg/hulaoguan.png"
const GROUND_PATH := "res://assets/bg/hulaoguan_ground.png"
const MAP_SIZE := Vector2(1672, 941)
const TROOP_SHADER := preload("res://shaders/troop_tint.gdshader")
const FLAG_SHADER := preload("res://shaders/flag_wave.gdshader")
const Flag := preload("res://scripts/battle/fx/war_flag.gd")
const Troop := preload("res://scripts/battle/fx/troop.gd")

var battle: Node
var map_sprite: Sprite2D
var under: Sprite2D
var troops: Array = []         # 每个兵卒节点
var flags: Array = []
var rays: Node2D
var motes: CPUParticles2D
var gust: CPUParticles2D
var gust_t := 6.0
var preset := {}
var actors: Node2D


const PRESETS := {
	"chen": {"name": "辰时", "map": Color(0.97, 1.0, 1.04), "actor": Color(1.0, 1.0, 1.02), "map_sat": 0.84, "map_bright": 1.0,
		"haze": Color(0.82, 0.86, 0.92), "grade": Color(0.99, 1.0, 1.02), "lift": Color(0.0, 0.004, 0.012), "vignette": 0.26, "sat": 1.0, "contrast": 1.02,
		"ray": Color(1.0, 0.98, 0.9), "ray_a": 0.07, "dust": Color(1.0, 0.97, 0.9, 0.3), "motes": 60},
	"wu": {"name": "午时", "map": Color(1.02, 1.0, 0.97), "actor": Color(1.0, 1.0, 1.0), "map_sat": 0.86, "map_bright": 1.0,
		"haze": Color(0.86, 0.82, 0.76), "grade": Color(1.0, 1.0, 0.99), "lift": Color(0.0, 0.0, 0.0), "vignette": 0.24, "sat": 1.02, "contrast": 1.03,
		"ray": Color(1.0, 0.95, 0.8), "ray_a": 0.05, "dust": Color(1.0, 0.92, 0.75, 0.3), "motes": 50},
	"you": {"name": "酉时", "map": Color(1.03, 0.96, 0.9), "actor": Color(1.02, 0.98, 0.95), "map_sat": 0.8, "map_bright": 0.97,
		"haze": Color(0.95, 0.72, 0.55), "grade": Color(1.02, 0.98, 0.95), "lift": Color(0.01, 0.0, 0.0), "vignette": 0.32, "sat": 1.0, "contrast": 1.03,
		"ray": Color(1.0, 0.62, 0.3), "ray_a": 0.14, "dust": Color(1.0, 0.75, 0.45, 0.4), "motes": 70},
	"sha": {"name": "黄沙", "map": Color(1.0, 0.96, 0.9), "actor": Color(1.0, 0.98, 0.95), "map_sat": 0.74, "map_bright": 1.02,
		"haze": Color(0.9, 0.82, 0.66), "grade": Color(1.0, 0.98, 0.95), "lift": Color(0.02, 0.014, 0.0), "vignette": 0.3, "sat": 0.95, "contrast": 1.0,
		"ray": Color(1.0, 0.85, 0.6), "ray_a": 0.05, "dust": Color(0.9, 0.78, 0.55, 0.5), "motes": 140},
}


func build(p_battle: Node, p_actors: Node2D, preset_key: String) -> void:
	battle = p_battle
	actors = p_actors
	preset = PRESETS.get(preset_key, PRESETS["wu"])
	if ResourceLoader.exists(GROUND_PATH):
		under = Sprite2D.new()
		under.texture = load(GROUND_PATH)
		under.position = MAP_SIZE * 0.5 + Vector2(0, 80)
		var gs := Vector2(2600, 1200) / Vector2(under.texture.get_size())
		under.scale = gs
		under.modulate = preset["map"]
		add_child(under)
	map_sprite = Sprite2D.new()
	map_sprite.centered = false
	if ResourceLoader.exists(MAP_PATH):
		map_sprite.texture = load(MAP_PATH)
		map_sprite.scale = MAP_SIZE / Vector2(map_sprite.texture.get_size())
	map_sprite.modulate = preset["map"]
	var mm := ShaderMaterial.new()
	mm.shader = preload("res://shaders/map_grade.gdshader")
	mm.set_shader_parameter("saturation", preset.get("map_sat", 0.8))
	mm.set_shader_parameter("brightness", preset.get("map_bright", 0.93))
	mm.set_shader_parameter("haze_color", preset.get("haze", Color(0.8, 0.76, 0.7)))
	map_sprite.material = mm
	add_child(map_sprite)
	if under:
		under.material = mm
	_build_troops()
	_build_motes()
	rays = Node2D.new()
	rays.set_script(preload("res://scripts/battle/fx/light_rays.gd"))
	rays.set("color", preset["ray"])
	rays.set("strength", float(preset["ray_a"]))
	rays.z_index = 38
	add_child(rays)


func _build_troops() -> void:
	var kinds := ["spear", "sword_shield", "archer", "spear", "cavalry", "sword_shield", "archer"]
	# 左方（我军）：沿栅栏一字排开；右方（敌军）对称
	var rows := [
		[Vector2(150, 560), Vector2(196, 640), Vector2(140, 724), Vector2(200, 808), Vector2(150, 900), Vector2(236, 486)],
		[Vector2(1524, 560), Vector2(1478, 640), Vector2(1532, 724), Vector2(1474, 808), Vector2(1524, 900), Vector2(1436, 486)],
	]
	for side in 2:
		for i in rows[side].size():
			var kind: String = kinds[(i + side * 2) % kinds.size()]
			var tr := Troop.new()
			tr.kind = kind
			tr.side = side
			tr.position = rows[side][i]
			tr.facing = 1 if side == 0 else -1
			tr.tint_shader = TROOP_SHADER
			actors.add_child(tr)
			if not tr.ok:
				tr.queue_free()
				continue
			tr.modulate = preset["actor"]
			troops.append(tr)


func build_flags(left_id: String, right_id: String) -> void:
	for f in flags:
		f.queue_free()
	flags.clear()
	var spots := [Vector2(300, 452), Vector2(1372, 452)]
	for side in 2:
		var gid := left_id if side == 0 else right_id
		var d := Roster.get_def(gid)
		var fl := Flag.new()
		fl.position = spots[side]
		fl.text = d["name"].substr(0, 1)
		fl.cloth = Color(d["color"]).darkened(0.35) if side == 0 else Color(d["color"]).darkened(0.45)
		fl.trim = Color(1.0, 0.82, 0.35)
		fl.facing = 1 if side == 0 else -1
		fl.wave_shader = FLAG_SHADER
		actors.add_child(fl)
		fl.modulate = preset["actor"]
		flags.append(fl)


func _build_motes() -> void:
	motes = CPUParticles2D.new()
	motes.amount = int(preset["motes"])
	motes.lifetime = 9.0
	motes.preprocess = 9.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(900, 420)
	motes.position = Vector2(836, 520)
	motes.direction = Vector2(1, -0.15)
	motes.spread = 25.0
	motes.gravity = Vector2(0, -4)
	motes.initial_velocity_min = 12.0
	motes.initial_velocity_max = 38.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 3.2
	motes.color = preset["dust"]
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.add_point(0.8, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	motes.color_ramp = ramp
	motes.z_index = 40
	add_child(motes)
	gust = CPUParticles2D.new()
	gust.emitting = false
	gust.one_shot = true
	gust.amount = 70
	gust.lifetime = 2.6
	gust.explosiveness = 0.15
	gust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	gust.emission_rect_extents = Vector2(40, 260)
	gust.position = Vector2(-60, 700)
	gust.direction = Vector2(1, -0.05)
	gust.spread = 6.0
	gust.gravity = Vector2(0, 0)
	gust.initial_velocity_min = 520.0
	gust.initial_velocity_max = 900.0
	gust.scale_amount_min = 2.0
	gust.scale_amount_max = 6.0
	gust.color = Color(preset["dust"].r, preset["dust"].g, preset["dust"].b, 0.5)
	gust.color_ramp = ramp
	gust.z_index = 41
	add_child(gust)


func _process(delta: float) -> void:
	gust_t -= delta
	if gust_t <= 0.0:
		gust_t = randf_range(9.0, 18.0)
		gust.position = Vector2(-60, randf_range(520, 860))
		gust.restart()
		gust.emitting = true
		Sfx.play("wind", -14.0, randf_range(0.9, 1.1))


## 助威：side 一方兵卒欢呼。power 0..1
var _cheer_snd_t := 0
var _ooh_snd_t := 0


func cheer(side: int, power := 1.0) -> void:
	for tr in troops:
		if tr.side == side:
			tr.cheer(power)
	var now := Time.get_ticks_msec()
	if power > 0.6 and now > _cheer_snd_t:
		_cheer_snd_t = now + 2600
		Sfx.play("crowd_cheer", -9.0 + power * 3.0)


## 惊愕：己方主将遭重创
func gasp(side: int) -> void:
	for tr in troops:
		if tr.side == side:
			tr.gasp()
	var now := Time.get_ticks_msec()
	if now > _ooh_snd_t:
		_ooh_snd_t = now + 1800
		Sfx.play("crowd_ooh", -10.0)


func troops_face_center() -> void:
	pass
