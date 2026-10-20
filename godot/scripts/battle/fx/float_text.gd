extends Node2D
## 飘字：伤害数字、"拆招""破防"等印章字。kind: number / crit / stamp / small

var text := ""
var kind := "number"
var color := Color(1, 0.9, 0.6)
var font: Font
var size := 44
var life := 0.9
var t := 0.0
var vel := Vector2(0, -90)
var rot := 0.0


func _ready() -> void:
	if kind == "stamp":
		life = 1.1
		vel = Vector2(0, -24)
		rot = randf_range(-0.12, 0.12)
	elif kind == "crit":
		life = 1.0
		vel = Vector2(randf_range(-30, 30), -120)
	else:
		vel = Vector2(randf_range(-40, 40), -110)


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	position += vel * delta
	vel *= pow(0.25, delta)
	_keep_below_hud()
	queue_redraw()


func _keep_below_hud() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var z := cam.zoom.x
	var center := cam.get_screen_center_position()
	var top := center.y - 540.0 / z + (250.0 if kind == "stamp" else 200.0) / z
	if position.y < top:
		position.y = top


func _draw() -> void:
	if font == null:
		return
	var use_font: Font = Game.font_brush if kind == "stamp" else font
	var pop := 1.0
	if kind == "stamp":
		pop = lerp(2.2, 1.0, clamp(t / 0.12, 0.0, 1.0))
		if t < 0.12:
			pop += sin(t / 0.12 * PI) * 0.1
	else:
		pop = lerp(1.7, 1.0, clamp(t / 0.1, 0.0, 1.0))
	var fade: float = 1.0 - clamp((t - life * 0.6) / (life * 0.4), 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, rot, Vector2(pop, pop))
	var sz := size
	var w := use_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var pos := Vector2(-w * 0.5, sz * 0.35)
	var outline := Color(0.12, 0.03, 0.02, fade)
	draw_string_outline(use_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 10 if kind == "stamp" else 7, outline)
	var c := Color(color.r, color.g, color.b, fade)
	draw_string(use_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
