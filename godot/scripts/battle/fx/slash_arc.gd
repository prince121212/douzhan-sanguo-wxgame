extends Node2D
## 刀光：从 a0 扫到 a1 的扇形月牙。
##
## 三层结构（这是让它「像斩击」而不是「像香蕉」的关键）：
##   1. 扇面填充：从圆心扫出去的一大片半透明光，表示兵器扫过的整个区域
##   2. 主弧带：贴着外缘的厚月牙，越靠头部越亮越粗
##   3. 亮芯 + 前缘：一条几乎纯白的细弧，卡在扫击最前端
## 再加一串沿弧飞散的火星，把「速度」画出来。

var radius := 120.0
var thickness := 34.0
var a0 := -1.0
var a1 := 1.0
var color := Color(1, 0.9, 0.6)
var life := 0.26
var sweep_time := 0.07
var t := 0.0
var squash_y := 0.55
var sparks := true

var _spark_seed: Array = []


func _ready() -> void:
	# 沿弧随机撒火星（固定随机种子，回放时一致）
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(a1 - a0) * 1000.0) + int(radius)
	var n := 16 if sparks else 0
	for i in n:
		_spark_seed.append([
			rng.randf(),                       # 在弧上的位置 0..1
			rng.randf_range(0.82, 1.16),       # 半径倍率
			rng.randf_range(0.5, 1.4),         # 长度倍率
			rng.randf_range(-1.0, 1.0),        # 切向偏移
		])


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _pt(a: float, r: float) -> Vector2:
	return Vector2(cos(a) * r, sin(a) * r * squash_y)


func _draw() -> void:
	var sweep: float = clampf(t / maxf(0.001, sweep_time), 0.0, 1.0)
	sweep = 1.0 - pow(1.0 - sweep, 3.0)          # 先快后慢，出手干脆
	var fade: float = 1.0 - clampf((t - sweep_time) / maxf(0.001, life - sweep_time), 0.0, 1.0)
	var head: float = lerpf(a0, a1, sweep)
	# 尾巴在 sweep 完成后开始追上来（残影拖尾）
	var tail: float = lerpf(a0, head, clampf((t - sweep_time * 0.5) / life * 1.4, 0.0, 0.92))
	var seg := 26
	var dir := signf(a1 - a0) if absf(a1 - a0) > 0.001 else 1.0
	var span := absf(head - tail)
	if span < 0.004:
		return

	# ---- 1) 扇面填充：从圆心扫出的整片光 ----
	# 扇面填充只做「扫过的空气被点亮」的暗示，alpha 必须很低：
	# 稍高一点就变成一块实心扇形饼，和突刺那个 bug 是同一种观感错误。
	# 回旋斩（总跨度 > 180°）直接不画：从圆心铺满一圈就是一个实心圆盘。
	# 注意判断必须用「总跨度」而不是当前 span：否则回旋斩开头几帧会画、
	# 之后突然消失，肉眼就是一次闪烁。
	if absf(a1 - a0) < PI * 0.85:
		_fan(tail, head, radius * 0.90, Color(color.r * 0.42, color.g * 0.42, color.b * 0.42, 0.030 * fade), seg)

	# ---- 2) 主弧带（粗 → 细，头亮尾暗）----
	var w_max := thickness
	var prev_o := Vector2.ZERO
	var prev_i := Vector2.ZERO
	for i in seg + 1:
		var u := float(i) / float(seg)
		var a: float = lerpf(tail, head, u)
		var taper: float = pow(u, 0.35)          # 尾部极细、头部粗，做出「刀锋」的锐利感
		# 尾部收到 0（不然是一个齐口），头部最后 8% 略收，避免平头
		var w: float = w_max * taper * (1.0 - 0.55 * smoothstep(0.92, 1.0, u))
		var r_out := radius + w * 0.5
		var r_in := radius - w * 0.5
		var po := _pt(a, r_out)
		var pi_ := _pt(a, r_in)
		if i > 0:
			# 亮度别超过 1：这层现在是普通混合（加法在沙地上会整条冲白）
			var hot: float = lerpf(0.85, 1.05, u)         # 头部略亮
			var al: float = fade * lerpf(0.55, 1.0, u)
			var c := Color(minf(color.r * hot, 1.0), minf(color.g * hot, 1.0),
				minf(color.b * hot, 1.0), al)
			draw_primitive(PackedVector2Array([prev_o, po, pi_, prev_i]),
				PackedColorArray([c, c, c, c]), PackedVector2Array())
		prev_o = po
		prev_i = pi_

	# ---- 3) 亮芯：贴外缘的细白线 ----
	# 半径必须跟着局部宽度走：固定半径的话，刀尾（宽度≈0）会甩出一根
	# 悬在弧外的白线。
	var core_pts := PackedVector2Array()
	for i in seg + 1:
		var u := float(i) / float(seg)
		var taper_c: float = pow(u, 0.35)
		var wc: float = w_max * taper_c * (1.0 - 0.55 * smoothstep(0.92, 1.0, u))
		core_pts.append(_pt(lerpf(tail, head, u), radius + wc * 0.5 * 0.72))
	if core_pts.size() >= 2:
		draw_polyline(core_pts, Color(1, 1, 1, 0.55 * fade), maxf(1.0, w_max * 0.10), true)

	# ---- 4) 前缘：扫击最前端的一小段白弧 ----
	# 不能用 draw_polyline 画粗线：线宽大于弧长时，末端会被截成一块方头
	# （在回旋斩上就是个明显的白色方块）。这里手工做四边形，两端收尖。
	if sweep < 1.0:
		var a_lo: float = head - dir * 0.20
		var hw := w_max * 0.30
		var n2 := 8
		var prev_a := Vector2.ZERO
		var prev_b := Vector2.ZERO
		for i in n2 + 1:
			var u := float(i) / float(n2)
			var ang: float = lerpf(a_lo, head, u)
			# 两端收尖，中段最粗
			var taper2: float = sin(PI * u)
			var r_out := radius + hw * taper2
			var r_in := radius - hw * taper2
			var pa := _pt(ang, r_out)
			var pb := _pt(ang, r_in)
			if i > 0:
				var c := Color(1.0, 1.0, 1.0, 0.60 * fade * taper2)
				draw_primitive(PackedVector2Array([prev_a, pa, pb, prev_b]),
					PackedColorArray([c, c, c, c]), PackedVector2Array())
			prev_a = pa
			prev_b = pb

	# ---- 5) 沿弧飞散的火星 ----
	if sparks and fade > 0.05:
		for s in _spark_seed:
			var u: float = float(s[0])
			# 只有已经被扫过的部分才出火星
			if u > sweep + 0.06:
				continue
			var a2: float = lerpf(a0, a1, u)
			var r2: float = radius * float(s[1])
			var p := _pt(a2, r2)
			var tangent := Vector2(-sin(a2), cos(a2) * squash_y).normalized()
			var len2: float = 22.0 * float(s[2]) * fade
			var side := float(s[3]) * 8.0 * fade
			var q := p + tangent * len2 + _pt(a2, r2 + side) - p
			draw_line(p, q, Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 0.7 * fade), maxf(0.8, 2.2 * fade), true)


## 用三角形扇填充一段圆弧
func _fan(from_a: float, to_a: float, r: float, col: Color, seg: int) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	for i in seg + 1:
		pts.append(_pt(lerpf(from_a, to_a, float(i) / float(seg)), r))
	# pts = 圆心 + seg+1 个弧点，共 seg+2 个；三角形从 0,i+1,i+2 取，最多到 seg
	var seg_n := pts.size() - 2
	for i in seg_n:
		draw_primitive(PackedVector2Array([pts[0], pts[i + 1], pts[i + 2]]),
			PackedColorArray([col, col, col]), PackedVector2Array())
