extends Node2D
## 百步穿杨的锁定准星：从大圈收拢到目标身上。

var target: Node2D
var life := 1.0
var t := 0.0
var color := Color(1.0, 0.85, 0.3)


func _process(delta: float) -> void:
	t += delta
	if t >= life or not is_instance_valid(target):
		queue_free()
		return
	global_position = target.center_global()
	queue_redraw()


func _draw() -> void:
	var k: float = clamp(t / (life * 0.7), 0.0, 1.0)
	var r: float = lerp(240.0, 60.0, 1.0 - pow(1.0 - k, 3.0))
	var a: float = 0.4 + k * 0.6
	var c := Color(color.r * 2.0, color.g * 2.0, color.b * 1.5, a)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c, 4.0)
	draw_arc(Vector2.ZERO, r * 0.6, t * 3.0, t * 3.0 + PI * 1.4, 24, c, 3.0)
	for i in 4:
		var ang := TAU * i / 4.0 + t * 1.5
		var d := Vector2(cos(ang), sin(ang))
		draw_line(d * (r + 10.0), d * (r + 40.0), c, 4.0)
	if k >= 1.0:
		draw_circle(Vector2.ZERO, 8.0, Color(3, 2.5, 1.2, 1))
