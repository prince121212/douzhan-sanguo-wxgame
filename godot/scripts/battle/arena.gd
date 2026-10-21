extends Node2D
## 虎牢关战场：底图、两侧助威的兵卒、帅旗、飞尘、光束、时辰光照。

# 地图/地面/尺寸/时辰预设全部来自 config/arena.json（Cfg.arena()）。
# 换主题 = 换配置里的一个 arena 条目 + 放好贴图，代码不用动。
const DEFAULT_ARENA := "hulaoguan"
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
var arena_def := {}
var map_size := Vector2(1672, 941)
var actors: Node2D




func _vec(v, fallback: Vector2) -> Vector2:
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback


func build(p_battle: Node, p_actors: Node2D, preset_key: String) -> void:
	battle = p_battle
	actors = p_actors
	arena_def = Cfg.arena(Game.arena_id if Game.arena_id != "" else DEFAULT_ARENA)
	map_size = _vec(arena_def.get("size", [1672, 941]), Vector2(1672, 941))
	var presets: Dictionary = arena_def.get("presets", {})
	preset = presets.get(preset_key, presets.get("wu", {}))
	if preset.is_empty():
		preset = {"name": "", "map": Color.WHITE, "actor": Color.WHITE, "ray": Color.WHITE,
			"ray_a": 0.0, "dust": Color(1, 1, 1, 0.3), "motes": 40}

	var ground_path: String = arena_def.get("ground", "")
	if ground_path != "" and ResourceLoader.exists(ground_path):
		under = Sprite2D.new()
		under.texture = load(ground_path)
		under.position = map_size * 0.5 + Vector2(0, 80)
		var gsz := _vec(arena_def.get("ground_scale", [2600, 1200]), Vector2(2600, 1200))
		under.scale = gsz / Vector2(under.texture.get_size())
		under.modulate = preset.get("map", Color.WHITE)
		add_child(under)
	map_sprite = Sprite2D.new()
	map_sprite.centered = false
	var map_path: String = arena_def.get("map", "")
	if map_path != "" and ResourceLoader.exists(map_path):
		map_sprite.texture = load(map_path)
		map_sprite.scale = map_size / Vector2(map_sprite.texture.get_size())
	map_sprite.modulate = preset.get("map", Color.WHITE)
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
	rays.set("color", preset.get("ray", Color.WHITE))
	rays.set("strength", float(preset.get("ray_a", 0.0)))
	rays.z_index = 38
	add_child(rays)


func _build_troops() -> void:
	var kinds := ["spear", "sword_shield", "archer", "spear", "cavalry", "sword_shield", "archer"]
	# 左方（我军）：沿栅栏一字排开；右方（敌军）对称
	# 摆位用「地图尺寸的百分比」，换地图（尺寸不同）时自动跟着缩放
	var rel := [
		[Vector2(0.090, 0.595), Vector2(0.117, 0.680), Vector2(0.084, 0.769), Vector2(0.120, 0.859), Vector2(0.090, 0.956), Vector2(0.141, 0.516)],
		[Vector2(0.911, 0.595), Vector2(0.884, 0.680), Vector2(0.916, 0.769), Vector2(0.882, 0.859), Vector2(0.911, 0.956), Vector2(0.859, 0.516)],
	]
	var rows := []
	for side in 2:
		var row := []
		for p in rel[side]:
			row.append(Vector2(p.x * map_size.x, p.y * map_size.y))
		rows.append(row)
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
			tr.modulate = preset.get("actor", Color.WHITE)
			troops.append(tr)


func build_flags(left_id: String, right_id: String) -> void:
	for f in flags:
		f.queue_free()
	flags.clear()
	var spots := [Vector2(0.179 * map_size.x, 0.480 * map_size.y), Vector2(0.821 * map_size.x, 0.480 * map_size.y)]
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
		fl.modulate = preset.get("actor", Color.WHITE)
		flags.append(fl)


func _build_motes() -> void:
	motes = CPUParticles2D.new()
	motes.amount = int(preset.get("motes", 40))
	motes.lifetime = 9.0
	motes.preprocess = 9.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(900, 420)
	motes.position = map_size * 0.5
	motes.direction = Vector2(1, -0.15)
	motes.spread = 25.0
	motes.gravity = Vector2(0, -4)
	motes.initial_velocity_min = 12.0
	motes.initial_velocity_max = 38.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 3.2
	motes.color = preset.get("dust", Color(1,1,1,0.3))
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
	var dust: Color = preset.get("dust", Color(1, 1, 1, 0.3))
	gust.color = Color(dust.r, dust.g, dust.b, 0.5)
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
