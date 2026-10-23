extends Node2D
## 沿弧飞散的火星：刀光扫过时，刃口甩出去的一串余烬。
##
## 为什么要有：刀光本身是「一条带」，扫完就没了，画面会显得干净得发假。
## 真实的高温斩击会在刃口甩出一串火星，沿切线方向飞出去、带着拖尾慢慢熄。
## 这一层只加「碎屑」，不加亮度——它负责把刀光和地面连起来。
##
## 每颗火星：
##   起点 = 弧上随机一点
##   速度 = 切线方向(主) + 径向向外(次)，再叠一点随机
##   受力 = 重力（往下掉）+ 阻尼（很快停）
##   绘制 = 一条短线（沿速度方向），长度随速度衰减

var color := Color(1.0, 0.6, 0.2)
var radius := 150.0
var a0 := -60.0
var a1 := 60.0
var count := 14
var life := 0.55
var speed := 260.0
var t := 0.0
var _bits: Array = []


func _ready() -> void:
	for i in count:
		var u := randf()
		# 往刀尖那头多撒一些：刀尖速度快，火星应该更密
		u = pow(u, 0.65)
		var ang := deg_to_rad(lerpf(a0, a1, u))
		var dir := Vector2(cos(ang), sin(ang))
		var tan := Vector2(-dir.y, dir.x)
		# 切线方向决定甩出去的方向：a1 > a0 时扫的方向是角度增大的方向
		var sweep_dir := 1.0 if a1 > a0 else -1.0
		# 火星主要「顺着刃口甩」，不是「往下掉」：径向分量小，重力也轻。
		# 重力一大就变成一串红色水滴，读起来像血，不像火。
		# 速度也别太大：飞太远就变成屏幕上乱飘的白道子，读起来像 bug。
		var v := tan * sweep_dir * speed * randf_range(0.75, 1.35)
		v += dir * speed * randf_range(0.05, 0.22)
		v.y += randf_range(-70.0, 10.0)
		_bits.append({
			"p": dir * radius * randf_range(0.94, 1.04),
			"v": v,
			"s": randf_range(1.5, 2.8),
			"life": life * randf_range(0.55, 1.0),
			"t": randf_range(0.0, 0.10),
			"on": false,
		})


func _process(delta: float) -> void:
	t += delta
	var any := false
	for b in _bits:
		if not b["on"]:
			if t >= b["t"]:
				b["on"] = true
			else:
				any = true
				continue
		b["v"] *= pow(0.004, delta)
		b["v"].y += 55.0 * delta
		b["p"] += b["v"] * delta
		any = true
	if not any or t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for b in _bits:
		if not b["on"]:
			continue
		var k: float = clampf((t - b["t"]) / maxf(0.05, b["life"]), 0.0, 1.0)
		var fade: float = 1.0 - k
		var v: Vector2 = b["v"]
		# 速度越快拖尾越长；停下后只剩一个小亮点
		var tail: Vector2 = -v * 0.030
		# 火星比刀光更黄更亮：它是「溅出来的铁屑」，不是刀光的复制品。
		# 用主题色起手，但把红绿拉高、蓝压死——火花永远是暖的。
		# 颜色不超过 1：这层走普通混合，超过 1 只会被 clamp。
		var c := Color(minf(color.r * 1.35 + 0.35, 1.0), minf(color.g * 1.15 + 0.22, 1.0),
			minf(color.b * 0.55 + 0.08, 1.0), 0.92 * fade)
		draw_line(b["p"], b["p"] + tail, c, b["s"] * fade + 0.35)
		# 头部的白热点
		draw_circle(b["p"], b["s"] * 0.34 * fade + 0.20, Color(1.0, 0.95, 0.80, 0.55 * fade))
