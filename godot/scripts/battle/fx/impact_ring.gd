extends Node2D
## 命中冲击：一圈会「胀开 + 变薄 + 断开」的破碎环，外加放射短线。
## 和原来的 ring_wave 区别：这个带随机缺口和粗细变化，看起来像被震碎的空气，不是完美的圆。

var r0 := 20.0
var r1 := 140.0
var color := Color(1, 0.9, 0.6)
var life := 0.28
var t := 0.0
var segs: Array = []     # [起角, 终角, 宽度倍率]
var streak := true


func _ready() -> void:
	# 只保留约 60% 的弧段：有断口才像被震碎的空气，连起来就是个靶子
	var n := 20
	for i in n:
		if randf() < 0.4:
			continue
		var a0 := TAU * float(i) / float(n)
		var span := TAU / float(n) * randf_range(0.35, 0.95)
		segs.append([a0, a0 + span, randf_range(0.35, 1.2)])


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = t / life
	var e: float = 1.0 - pow(1.0 - k, 2.4)
	var r: float = lerpf(r0, r1, e)
	var fade: float = 1.0 - k
	# 主环：分段画，带缺口
	for s in segs:
		var a0: float = s[0]
		var a1: float = s[1]
		var w: float = 6.0 * float(s[2]) * fade + 0.8
		var c := Color(color.r * 1.35, color.g * 1.35, color.b * 1.35, fade * 0.55)
		draw_arc(Vector2.ZERO, r, a0, a1, 10, c, w, true)
		var c2 := Color(1, 1, 1, fade * 0.60)
		draw_arc(Vector2.ZERO, r, a0, a1, 10, c2, maxf(0.8, w * 0.3), true)
	if streak:
		# 放射短线
		for s in segs:
			if randf() < 0.5:
				continue
			var a: float = (s[0] + s[1]) * 0.5
			var d := Vector2(cos(a), sin(a))
			var l0 := r * 0.82
			var l1 := r * (1.0 + 0.35 * fade)
			draw_line(d * l0, d * l1, Color(color.r * 1.3, color.g * 1.3, color.b * 1.3, fade * 0.35), maxf(0.8, 2.0 * fade))
