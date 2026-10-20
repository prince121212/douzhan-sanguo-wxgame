extends Node2D
## 刀气：一道竖立的巨大月牙向前飞行，身后拖着光尾。

var vx := 1500.0
var color := Color(0.4, 1.0, 0.6)
var height := 260.0
var life := 1.2
var t := 0.0
var trail: Array = []


func _process(delta: float) -> void:
	t += delta
	position.x += vx * delta
	trail.push_front(position.x)
	if trail.size() > 14:
		trail.pop_back()
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _crescent(cx: float, a: float, scale_w: float) -> void:
	var dir := signf(vx)
	var h := height
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 21:
		var u := float(i) / 20.0
		var y := lerpf(-h, 0.0, u)
		var bulge := sin(u * PI)
		outer.append(Vector2(cx + dir * bulge * 70.0 * scale_w, y))
		inner.append(Vector2(cx + dir * bulge * 30.0 * scale_w, y))
	inner.reverse()
	var poly := outer + inner
	draw_colored_polygon(poly, Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, a))


func _draw() -> void:
	var fade: float = 1.0 - clamp((t - life + 0.3) / 0.3, 0.0, 1.0)
	for i in range(trail.size() - 1, 0, -1):
		var a := (1.0 - float(i) / trail.size()) * 0.25 * fade
		_crescent(trail[i] - position.x, a, 0.8)
	_crescent(0.0, 0.85 * fade, 1.2)
	_crescent(0.0, 1.0 * fade, 0.5)
	draw_line(Vector2(0, -height), Vector2(0, 0), Color(3, 3, 3, fade), 4.0)
