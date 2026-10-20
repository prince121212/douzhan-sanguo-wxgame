extends Node2D
## 场边助威的兵卒：8 帧欢呼循环，主将得手时更起劲，挨重击时愣住。

var kind := "spear"
var side := 0
var facing := 1
var tint_shader: Shader
var ok := false
var frames: Array = []
var sprite: Sprite2D
var mat: ShaderMaterial
var anchor := Vector2.ZERO
var phase := 0.0
var fps := 5.0
var excite := 0.0
var stun := 0.0
var hop := 0.0
var t := 0.0
var shadow: Node2D


func _ready() -> void:
	var data: Array = Bank.troop_frames(kind)
	if data.is_empty():
		return
	frames = data[0]["frames"]
	if frames.is_empty():
		return
	var entry: Dictionary = data[0]["entry"]
	var tex: Texture2D = frames[0]
	anchor = Vector2(tex.get_width() * 0.5, tex.get_height())
	if entry.has("anchor"):
		anchor = Vector2(entry["anchor"][0], entry["anchor"][1])
	var h_src := float(entry.get("stand_height", tex.get_height()))
	var target := 96.0 if kind == "cavalry" else 76.0
	shadow = Node2D.new()
	shadow.set_script(preload("res://scripts/battle/fx/shadow_blob.gd"))
	shadow.set("radius", 36.0 if kind == "cavalry" else 22.0)
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture = tex
	sprite.offset = -anchor
	var sc: float = target / max(1.0, h_src)
	sprite.scale = Vector2(sc * facing, sc)
	mat = ShaderMaterial.new()
	mat.shader = tint_shader
	if side == 1:
		mat.set_shader_parameter("hue_shift", 0.6)
		mat.set_shader_parameter("sat_mult", 0.75)
		mat.set_shader_parameter("val_mult", 0.82)
	sprite.material = mat
	add_child(sprite)
	phase = randf() * 8.0
	fps = randf_range(3.6, 5.2)
	ok = true


func cheer(power: float) -> void:
	excite = max(excite, 0.6 + power * 0.8) * randf_range(0.85, 1.15)
	hop = max(hop, power * randf_range(0.6, 1.0))
	stun = 0.0


func gasp() -> void:
	stun = randf_range(0.6, 1.1)
	excite = 0.0


func _process(delta: float) -> void:
	if not ok:
		return
	t += delta
	excite = move_toward(excite, 0.0, delta * 0.45)
	if stun > 0.0:
		stun -= delta
		sprite.texture = frames[0]
		sprite.position = Vector2(-2.0 * facing, 0)
		sprite.rotation = -0.06 * facing
		return
	sprite.rotation = 0.0
	phase += delta * fps * (1.0 + excite * 2.2)
	var idx := int(phase) % frames.size()
	sprite.texture = frames[idx]
	hop = move_toward(hop, 0.0, delta * 1.6)
	var y := -absf(sin(t * 9.0)) * 18.0 * hop
	sprite.position = Vector2(0, y)
	shadow.set("height", -y)
	mat.set_shader_parameter("cheer_flash", excite * 0.05)
