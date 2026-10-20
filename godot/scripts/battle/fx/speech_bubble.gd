extends Node2D
## 头顶对白气泡：跟随武将，逐字显现。

var target: Node2D
var text := ""
var font: Font
var life := 2.2
var t := 0.0
var side := 0
var accent := Color(0.9, 0.2, 0.15)
var y_offset := 0.0


func _process(delta: float) -> void:
	t += delta
	if t >= life or not is_instance_valid(target):
		queue_free()
		return
	if target.has_method("head_global"):
		global_position = target.head_global() + Vector2(0, -26 - y_offset)
	_keep_on_screen()
	queue_redraw()


## 气泡别跑出屏幕，也别压到顶部血条
func _keep_on_screen() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or font == null:
		return
	var z := cam.zoom.x
	var half := Vector2(960, 540) / z
	var center := cam.get_screen_center_position()
	var w := (font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 44.0) * scale.x
	var hgt := 58.0 * scale.y
	var min_x := center.x - half.x + w * 0.5 + 20.0 / z
	var max_x := center.x + half.x - w * 0.5 - 20.0 / z
	var min_y := center.y - half.y + 210.0 / z + hgt
	global_position.x = clampf(global_position.x, min_x, max(min_x, max_x))
	global_position.y = maxf(global_position.y, min_y)


func _draw() -> void:
	if font == null:
		return
	var shown := text
	var chars := int(clamp(t * 26.0, 1.0, text.length()))
	shown = text.substr(0, chars)
	var sz := 30
	var full_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var pad := Vector2(22, 14)
	var w := full_w + pad.x * 2.0
	var hgt := sz + pad.y * 2.0
	var pop: float = clamp(t / 0.12, 0.0, 1.0)
	pop = 1.0 + sin(pop * PI) * 0.12 if pop < 1.0 else 1.0
	var fade: float = 1.0 - clamp((t - (life - 0.25)) / 0.25, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(pop, pop))
	var rect := Rect2(Vector2(-w * 0.5, -hgt), Vector2(w, hgt))
	var shadow := rect
	shadow.position += Vector2(4, 5)
	draw_rect(shadow, Color(0, 0, 0, 0.35 * fade))
	draw_rect(rect, Color(0.98, 0.95, 0.86, 0.96 * fade))
	draw_rect(rect, Color(0.18, 0.08, 0.06, fade), false, 4.0)
	draw_rect(Rect2(rect.position, Vector2(8, hgt)), Color(accent.r, accent.g, accent.b, fade))
	var tri := PackedVector2Array([Vector2(-12, 0), Vector2(12, 0), Vector2(0, 18)])
	draw_colored_polygon(tri, Color(0.98, 0.95, 0.86, 0.96 * fade))
	draw_polyline(PackedVector2Array([Vector2(-12, 0), Vector2(0, 18), Vector2(12, 0)]), Color(0.18, 0.08, 0.06, fade), 4.0)
	draw_string(font, Vector2(-full_w * 0.5 + 4, -pad.y - 6), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.16, 0.07, 0.05, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
