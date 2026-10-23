extends Node2D
## 冲击波。ground=true 时压扁成地面上的椭圆；否则是空中的碎裂冲击环。
##
## 为什么空中环必须断开：
##   一个闭合的完美圆在明亮沙地上就是一张靶纸——尤其当它正好套在
##   角色头上时，玩家第一反应是「UI 准星」，而不是「打中了」。
##   参考视频里没有这种环，冲击感全由星芒和火星承担。
##   所以空中环只保留几段带缺口的弧，且不做双层描边。

var color := Color(1, 0.9, 0.7)
var r0 := 20.0
var r1 := 220.0
var width := 14.0
var life := 0.45
var ground := false
var t := 0.0
## [起角, 终角, 宽度倍率]
var _segs: Array = []


func _ready() -> void:
	if ground:
		return
	var n := 14
	for i in n:
		# 只留约一半的弧段：断口才是「被震碎」的证据
		if randf() < 0.5:
			continue
		var a0 := TAU * float(i) / float(n)
		var span := TAU / float(n) * randf_range(0.25, 0.85)
		_segs.append([a0, a0 + span, randf_range(0.35, 1.0)])


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

	if ground:
		# 地面冲击波：保持完整椭圆，但压扁 + 单层，不要双描边
		var w: float = width * (1.0 - k * 0.6)
		var pts := PackedVector2Array()
		for i in 49:
			var ang := TAU * float(i) / 48.0
			pts.append(Vector2(cos(ang) * r, sin(ang) * r * 0.32))
		var c := Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, a * 0.55)
		draw_polyline(pts, c, w, true)
		return

	# 空中冲击环：几段断弧，越往外越细
	for s in _segs:
		var w: float = width * 0.42 * float(s[2]) * a + 0.6
		var c := Color(color.r * 1.15, color.g * 1.15, color.b * 1.15, a * 0.34)
		draw_arc(Vector2.ZERO, r, s[0], s[1], 8, c, w, true)
