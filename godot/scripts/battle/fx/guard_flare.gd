extends Node2D
## 格挡时身前的护体弧光。

var color := Color(1.0, 0.85, 0.4)
var life := 0.25
var t := 0.0
var facing := 1


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := t / life
	var a := (1.0 - k) * 0.8
	var r := 70.0 + k * 20.0
	var pts := PackedVector2Array()
	for i in 17:
		var ang := lerpf(-1.1, 1.1, float(i) / 16.0)
		pts.append(Vector2(cos(ang) * r * facing, sin(ang) * r * 1.2))
	draw_polyline(pts, Color(color.r * 2.0, color.g * 2.0, color.b * 1.6, a), 6.0)
	draw_polyline(pts, Color(color.r, color.g, color.b, a * 0.3), 16.0)
