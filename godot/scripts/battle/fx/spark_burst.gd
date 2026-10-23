extends Node2D
## 命中火花：四芒星 + 柔光晕 + 飞溅火星。
##
## 参考视频里的命中点是「四芒星」——四个方向的细长尖角，中心白热，
## 背后一圈同色柔光。尖角给方向感，柔光给体量，两者缺一不可。
##
## 为什么不是「白球 + 放射线」：
##   圆球在明亮沙地上会糊成一团白，读不出「打中了」；
##   随机射线会让命中点变成一团毛刺，反而没有方向。
##
## 分层：
##   1. 柔光晕  Sprite2D 子节点（普通混合）—— 体量
##   2. 四芒星  两张同款贴图叠加            —— 形状记忆点
##   3. 火星    带拖尾的暖色短线            —— 飞溅
##
## 为什么全部用普通混合：
##   沙地底色约 (0.80,0.66,0.46)。加法混合会把三个通道一起推到 255，
##   任何主题色都会变成纯白——星芒就成了一块白斑，色相全丢。

## 四芒星贴图（_tools/build_fx_star.py 生成）
const STAR_TEX := preload("res://assets/fx/star4.png")
## 径向柔光贴图
const GLOW_TEX := preload("res://assets/fx/glow_soft.png")

var color := Color(1.0, 0.85, 0.5)
var power := 1.0
var life := 0.32
var t := 0.0
var bits: Array = []
var big_flash := true
## 四芒星的整体旋转（弧度）。随机一点，避免每一下都一样。
var star_rot := 0.0
## 四芒星的长度（世界像素），由 power 推出
var star_len := 0.0


func _ready() -> void:
	star_rot = randf_range(-0.35, 0.35)
	# 尺寸克制：命中点通常压在对手的头部/兵器上，星芒太大就把角色盖住了。
	# 记忆点靠「细长的尖角」而不是「面积」——细才像光，粗就像贴纸。
	star_len = 30.0 + power * 14.0
	# 火星起点外推到星芒边缘之外：从正中心冒出来会和星芒挤成一团
	for i in int(5 + power * 5):
		var a := randf() * TAU
		var sp := randf_range(240.0, 700.0) * (0.7 + power * 0.5)
		var r0 := star_len * randf_range(0.62, 0.92)
		bits.append({"p": Vector2(cos(a), sin(a) * 0.8) * r0,
			"v": Vector2(cos(a), sin(a) * 0.7 - 0.25) * sp, "s": randf_range(1.1, 2.2)})


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
	# 星芒的时间曲线：前 45ms 猛地张开，之后缓慢缩、淡
	var open := clampf(t / 0.045, 0.0, 1.0)
	open = 1.0 - pow(1.0 - open, 3.0)
	var star_fade := 1.0 - clampf((t - 0.06) / maxf(0.02, life - 0.06), 0.0, 1.0)

	# ---- 1. 柔光晕 ----
	# 直接画在这里，不用子节点：子节点的 z_index 是相对父节点的，
	# 设 -1 会被角色/地面层盖住；设 0 又会盖住后面的星芒。
	# 光晕承担全部色相：尖刺是白的，颜色只在背后的光团里。
	var gr := star_len * (1.05 * open + 0.30 * k)
	# 光晕也跟着横向拉长，否则和星芒的形状对不上
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.18, 0.82))
	draw_texture_rect(GLOW_TEX, Rect2(-gr, -gr, gr * 2.0, gr * 2.0), false,
		Color(color.r, color.g, color.b, 1.0 * star_fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ---- 2. 四芒星：两层同款贴图，外层给色相，内层给白热芯 ----
	# big_flash=false（格挡火花）时仍然画，只是缩到 55% 且更淡：
	# 只留一团光晕的话，格挡就完全没有「被挡住」的反馈了。
	var star_scale := 1.0 if big_flash else 0.55
	var star_alpha := 1.0 if big_flash else 0.55
	var L := star_len * star_scale * (0.55 + 0.45 * open) * (1.0 - 0.16 * k)
	# 横向略长：斩击/突刺的接触面通常是横向的
	var sq := Vector2(1.18, 0.82)
	draw_set_transform(Vector2.ZERO, star_rot * 0.35, sq)
	# 外层：接近白，只留一点主题色相。
	# 参考视频里尖刺是白的、颜色在背后的光晕上——尖刺一旦上色，
	# 在沙地上就变成一块粉/蓝色块，读不出「高温」。
	var c_out := color.lerp(Color(1.0, 0.99, 0.95), 0.74)
	c_out = Color(minf(c_out.r * 1.10 + 0.04, 1.0), minf(c_out.g * 1.10 + 0.04, 1.0),
		minf(c_out.b * 1.06 + 0.03, 1.0))
	draw_texture_rect(STAR_TEX, Rect2(-L, -L, L * 2.0, L * 2.0), false,
		Color(c_out.r, c_out.g, c_out.b, 0.98 * star_fade * star_alpha))
	# 内层：白热芯，占 34% 宽度
	draw_texture_rect(STAR_TEX, Rect2(-L * 0.34, -L * 0.34, L * 0.68, L * 0.68), false,
		Color(1.0, 0.99, 0.97, 0.85 * star_fade * star_alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 中心白核：只是「过曝点」，不是一块白饼
	draw_circle(Vector2.ZERO, L * 0.040, Color(1.0, 1.0, 1.0, 0.90 * star_fade * star_alpha))

	# ---- 3. 火星：暖色短线 + 头部亮点 ----
	for b in bits:
		# 火星比刀光更黄更亮：它是「溅出来的铁屑」，不是刀光的复制品
		var c2 := Color(minf(color.r * 1.5, 1.0), minf(color.g * 1.25, 1.0), minf(color.b * 0.95, 1.0), fade)
		var v: Vector2 = b["v"]
		draw_line(b["p"], b["p"] - v * 0.02, c2, b["s"] * fade + 0.5)
