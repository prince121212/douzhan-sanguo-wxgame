extends Node2D
## 箭矢：在 (x, z, h) 空间飞行，带拖尾。由 battle 每帧检测命中。

var owner_f: Node2D
var vx := 1500.0
var vz := 0.0
var h := 80.0
var vh := 0.0
var dmg := 30.0
var mv: Dictionary = {}
var charge := 0.0
var life := 1.1
var pierce := false
var size := 1.0
var gold := false
var t := 0.0
var dead := false
var deflected := false
var trail: Array = []
var color := Color(1, 0.9, 0.6)


func _process(delta: float) -> void:
	t += delta
	position.x += vx * delta
	position.y += vz * delta
	h += vh * delta
	if deflected:
		vh -= 1600.0 * delta
	if t >= life or (deflected and h < -10.0):
		queue_free()
		return
	trail.push_front(Vector2(position.x, position.y - h))
	if trail.size() > 9:
		trail.pop_back()
	queue_redraw()


func _draw() -> void:
	var dir: float = signf(vx)
	var hp := Vector2(0, -h)
	var L := 46.0 * size
	var c := Color(0.95, 0.9, 0.8)
	# 拖尾
	for i in range(1, trail.size()):
		var a := 1.0 - float(i) / float(trail.size())
		var p0: Vector2 = trail[i - 1] - global_position
		var p1: Vector2 = trail[i] - global_position
		var tc := Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, a * (0.7 if gold else 0.35))
		draw_line(p0, p1, tc, (6.0 if gold else 3.0) * size * a + 1.0)
	var rot := 0.0
	if deflected:
		rot = t * 18.0
	draw_set_transform(hp, rot, Vector2(dir, 1))
	draw_line(Vector2(-L, 0), Vector2(0, 0), Color(0.45, 0.28, 0.14), 4.0 * size)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -6 * size), Vector2(14 * size, 0), Vector2(0, 6 * size)]), Color(0.85, 0.88, 0.92) if not gold else Color(2.4, 1.9, 0.8))
	draw_colored_polygon(PackedVector2Array([Vector2(-L, 0), Vector2(-L - 10 * size, -7 * size), Vector2(-L + 8 * size, 0)]), Color(0.95, 0.95, 0.95))
	draw_colored_polygon(PackedVector2Array([Vector2(-L, 0), Vector2(-L - 10 * size, 7 * size), Vector2(-L + 8 * size, 0)]), Color(0.85, 0.2, 0.15))
	if gold:
		draw_circle(Vector2(6, 0), 10.0 * size, Color(2.5, 2.0, 1.0, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
