extends Node2D
## 蓄力时向身体汇聚的光点。

var target_off := Vector2.ZERO
var start := Vector2.ZERO
var color := Color(1, 0.8, 0.4)
var life := 0.3
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = pow(t / life, 2.0)
	var p := start.lerp(target_off, k)
	var c := Color(color.r * 2.2, color.g * 2.2, color.b * 2.0, 1.0 - k * 0.5)
	draw_line(p, p + (target_off - start).normalized() * -18.0, c, 3.0)
	draw_circle(p, 3.5, c)
