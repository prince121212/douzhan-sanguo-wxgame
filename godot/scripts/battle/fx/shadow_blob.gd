extends Node2D
## 脚下的柔和椭圆影子，跳得越高越淡越小。

var radius := 40.0
var height := 0.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var k: float = clamp(1.0 - height / 320.0, 0.35, 1.0)
	var r: float = radius * k
	for i in 5:
		var t := float(i) / 4.0
		var rr: float = r * (1.25 - t * 0.45)
		var a: float = 0.07 + t * 0.07
		_ellipse(Vector2.ZERO, rr, rr * 0.3, Color(0.08, 0.05, 0.03, a * k))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
