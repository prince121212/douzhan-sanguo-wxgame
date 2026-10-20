extends Node2D
## 命中火花：中心闪光 + 放射状光刺 + 飞溅的火星。

var color := Color(1.0, 0.85, 0.5)
var power := 1.0
var life := 0.32
var t := 0.0
var rays: Array = []
var bits: Array = []
var big_flash := true


func _ready() -> void:
	var n := int(7 + power * 6)
	for i in n:
		var a := randf() * TAU
		rays.append([a, randf_range(0.5, 1.0) * (60.0 + power * 50.0), randf_range(3.0, 7.0) * (0.7 + power * 0.4)])
	for i in int(10 + power * 14):
		var a := randf() * TAU
		var sp := randf_range(200.0, 650.0) * (0.7 + power * 0.5)
		bits.append({"p": Vector2.ZERO, "v": Vector2(cos(a), sin(a) * 0.7 - 0.3) * sp, "s": randf_range(2.0, 4.5)})


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	for b in bits:
		b["v"] *= pow(0.02, delta)
		b["v"].y += 900.0 * delta
		b["p"] += b["v"] * delta
	queue_redraw()


func _draw() -> void:
	var k := t / life
	var fade := 1.0 - k
	if big_flash and t < 0.09:
		# 一闪：小而亮的核心 + 十字星芒，不要大白球
		var fk := 1.0 - t / 0.09
		var r := (8.0 + power * 5.0) * (1.0 + t * 8.0)
		draw_circle(Vector2.ZERO, r, Color(1.6, 1.5, 1.3, 0.7 * fk))
		var L := (60.0 + power * 55.0) * (0.6 + t * 6.0)
		var w := (5.0 + power * 2.5) * fk
		for ang in [0.0, PI * 0.5]:
			var d := Vector2(cos(ang), sin(ang))
			var n := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([d * L, n * w, -d * L, -n * w]), Color(2.0, 1.85, 1.5, 0.9 * fk))
	for ray in rays:
		var a: float = ray[0]
		var L: float = ray[1] * (0.4 + k * 0.9)
		var w: float = ray[2] * fade
		var dir := Vector2(cos(a), sin(a))
		var nrm := Vector2(-dir.y, dir.x)
		var p0 := dir * L * 0.25
		var p1 := dir * L
		var c := Color(color.r * 2.2, color.g * 2.2, color.b * 2.2, fade)
		draw_colored_polygon(PackedVector2Array([p0 + nrm * w, p1, p0 - nrm * w, dir * L * 0.1]), c)
	for b in bits:
		var c2 := Color(color.r * 2.5, color.g * 2.0, color.b * 1.5, fade)
		var v: Vector2 = b["v"]
		draw_line(b["p"], b["p"] - v * 0.02, c2, b["s"] * fade + 0.5)
