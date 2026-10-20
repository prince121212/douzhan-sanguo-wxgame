extends Node2D
## 突刺光：一道向前伸出的锥形光 + 几条速度线。

var length := 220.0
var width := 16.0
var color := Color(0.8, 0.9, 1.0)
var life := 0.22
var t := 0.0
var lines: Array = []


func _ready() -> void:
	for i in 5:
		lines.append([randf_range(-1.0, 1.0), randf_range(0.4, 1.0), randf_range(0.0, 0.3)])


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var grow: float = clamp(t / 0.06, 0.0, 1.0)
	grow = 1.0 - pow(1.0 - grow, 3.0)
	var fade: float = 1.0 - clamp((t - 0.05) / (life - 0.05), 0.0, 1.0)
	var L := length * grow
	var start := L * clampf((t - 0.04) / life, 0.0, 0.7)
	for layer in 3:
		var w: float = width * [1.3, 0.7, 0.25][layer]
		var col: Color = [color * Color(1, 1, 1, 0.22), color * Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.85)][layer]
		var hdr: float = [1.1, 1.35, 1.75][layer]
		col = Color(col.r * hdr, col.g * hdr, col.b * hdr, col.a * fade)
		var pts := PackedVector2Array([
			Vector2(start, -w * 0.25), Vector2(L * 0.75, -w * 0.5), Vector2(L, 0),
			Vector2(L * 0.75, w * 0.5), Vector2(start, w * 0.25)])
		draw_colored_polygon(pts, col)
	for ln in lines:
		var y: float = ln[0] * width * 2.4
		var len2: float = L * ln[1]
		var x0: float = L * ln[2] + start
		draw_line(Vector2(x0, y), Vector2(x0 + len2 * 0.6, y), Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.5 * fade), 2.0)
