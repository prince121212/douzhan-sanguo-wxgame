extends Node2D
## 地裂：重劈落地留下的裂纹，几秒后淡去。

var size := 1.0
var life := 3.0
var t := 0.0
var cracks: Array = []


func _ready() -> void:
	var n := int(6 + size * 4)
	for i in n:
		var a := TAU * float(i) / float(n) + randf_range(-0.25, 0.25)
		var pts := PackedVector2Array([Vector2.ZERO])
		var p := Vector2.ZERO
		var L := randf_range(40.0, 90.0) * size
		var steps := 6
		for s in steps:
			a += randf_range(-0.7, 0.7)
			p += Vector2(cos(a), sin(a) * 0.32) * L / steps
			pts.append(p)
		cracks.append(pts)


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a: float = 1.0 - clamp((t - life * 0.5) / (life * 0.5), 0.0, 1.0)
	var glow_a: float = 1.0 - clamp(t / 0.5, 0.0, 1.0)
	for pts in cracks:
		draw_polyline(pts, Color(0.32, 0.2, 0.11, 0.55 * a), 3.0)
		draw_polyline(pts, Color(0.2, 0.12, 0.06, 0.7 * a), 1.5)
		if glow_a > 0.0:
			draw_polyline(pts, Color(1.6, 1.0, 0.45, glow_a * 0.7), 1.5)
