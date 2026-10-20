extends Node2D
## 冲击波圆环。ground=true 时压扁成地面上的椭圆。

var color := Color(1, 0.9, 0.7)
var r0 := 20.0
var r1 := 220.0
var width := 14.0
var life := 0.45
var ground := false
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = 1.0 - pow(1.0 - t / life, 3.0)
	var r: float = lerp(r0, r1, k)
	var a: float = 1.0 - t / life
	var w: float = width * (1.0 - k * 0.6)
	var sy := 0.32 if ground else 1.0
	var pts := PackedVector2Array()
	for i in 49:
		var ang := TAU * float(i) / 48.0
		pts.append(Vector2(cos(ang) * r, sin(ang) * r * sy))
	var c := Color(color.r * 1.3, color.g * 1.3, color.b * 1.3, a * 0.85)
	draw_polyline(pts, c, w, true)
	var c2 := Color(color.r, color.g, color.b, a * 0.22)
	draw_polyline(pts, c2, w * 2.2, true)
