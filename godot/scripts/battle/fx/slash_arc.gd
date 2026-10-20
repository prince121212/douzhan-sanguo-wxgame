extends Node2D
## 刀光弧：从 a0 扫到 a1 的月牙，带亮芯与外晕，加色混合。

var radius := 120.0
var thickness := 34.0
var a0 := -1.0
var a1 := 1.0
var color := Color(1, 0.9, 0.6)
var life := 0.26
var sweep_time := 0.07
var t := 0.0
var squash_y := 0.55


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var sweep: float = clamp(t / sweep_time, 0.0, 1.0)
	sweep = 1.0 - pow(1.0 - sweep, 3.0)
	var fade: float = 1.0 - clamp((t - sweep_time) / (life - sweep_time), 0.0, 1.0)
	var head := lerpf(a0, a1, sweep)
	var tail_start: float = lerp(a0, a1, clamp((t - sweep_time * 0.4) / life, 0.0, 1.0) * 0.9)
	var seg := 26
	for layer in 3:
		var w: float = thickness * [1.0, 0.55, 0.22][layer]
		var col: Color = [color * Color(1, 1, 1, 0.35), color * Color(1, 1, 1, 0.7), Color(1.0, 1.0, 1.0, 1.0)][layer]
		col.a *= fade
		var hdr: float = [1.15, 1.45, 1.85][layer]
		col = Color(col.r * hdr, col.g * hdr, col.b * hdr, col.a)
		# 逐段画四边形：弧可以超过一整圈（旋风斩），单个多边形会自相交
		var prev_o := Vector2.ZERO
		var prev_i := Vector2.ZERO
		for i in seg + 1:
			var u := float(i) / float(seg)
			var a: float = lerp(tail_start, head, u)
			var taper := sin(u * PI * 0.5 + 0.0001)  # 尾部细、头部粗
			var r_out := radius + w * 0.5 * taper
			var r_in := radius - w * 0.5 * taper
			var po := Vector2(cos(a) * r_out, sin(a) * r_out * squash_y)
			var pi_ := Vector2(cos(a) * r_in, sin(a) * r_in * squash_y)
			if i > 0:
				var c2 := col
				c2.a *= 0.35 + 0.65 * u
				draw_primitive(PackedVector2Array([prev_o, po, pi_, prev_i]), PackedColorArray([c2, c2, c2, c2]), PackedVector2Array())
			prev_o = po
			prev_i = pi_
