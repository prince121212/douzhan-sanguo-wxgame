extends Node2D
## 突刺光：一道向前捅出的锥形光刃（细长、收尖、白热刃芯）。
##
## 为什么不是「扇形」：突刺是枪/戟沿一条直线捅出去，
## 视觉上必须是「细长、有方向、末端收尖」的光带。
## 画成扇形等于把「捅」画成了「扫」，玩家会读错招式。
##
## 分层（从外到内）：
##   1. 外焰  深橙红、最宽、最淡   —— 火的外轮廓
##   2. 主焰  橙、半透明           —— 主体
##   3. 亮芯  黄白、窄             —— 热芯
##   4. 刃芯  近白、最窄           —— 过曝的枪尖
## 出招 55ms 内推到全长，之后整体淡出，尾端先散。

var length := 220.0
var width := 16.0
var color := Color(1.0, 0.50, 0.14)
var life := 0.22
var t := 0.0
## 枪尖爆点强度（0 关闭）
var tip_flare := 1.0

const DEEP := Color(0.92, 0.18, 0.05)
const CORE := Color(1.0, 0.97, 0.88)

## 速度线：[横向偏移(-1..1), 长度比例, 起点比例]
var _lines: Array = []


func _ready() -> void:
	for i in 4:
		_lines.append([randf_range(-1.0, 1.0), randf_range(0.18, 0.34), randf_range(0.0, 0.25)])


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	# 出招：55ms 推到全长（ease-out），之后不再变长，只淡出
	var grow: float = clampf(t / 0.055, 0.0, 1.0)
	grow = 1.0 - pow(1.0 - grow, 3.0)
	# 整体透明度：前 55ms 全亮，之后淡出；最后 30% 尾端先散
	var fade: float = 1.0 - clampf((t - 0.055) / maxf(0.02, life - 0.055), 0.0, 1.0)
	var L: float = length * grow
	# 尾端消散比例：越到后面尾巴越短（光刃是「射出去」不是「缩回来」）
	var tail_cut: float = clampf((t - life * 0.5) / maxf(0.02, life * 0.5), 0.0, 0.55)
	var x0: float = L * tail_cut
	if L - x0 < 6.0:
		return
	# 轻微呼吸，别让边缘像尺子画的
	var wob: float = sin(t * 70.0) * width * 0.05

	# 层：宽度倍率 / 颜色 / 亮度 / 不透明度
	var layers := [
		[1.85, DEEP.lerp(color, 0.30), 1.00, 0.20],
		[1.10, color, 1.00, 0.52],
		[0.54, color.lerp(CORE, 0.55), 1.22, 0.74],
		[0.25, CORE, 1.55, 0.95],
	]
	var span: float = L - x0
	for l in layers:
		var w: float = width * float(l[0])
		var col: Color = l[1]
		var hdr: float = float(l[2])
		var a: float = float(l[3]) * fade
		col = Color(col.r * hdr, col.g * hdr, col.b * hdr, a)
		# 刀身：起点窄 → 0.3 处最宽 → 收尖
		var pts := PackedVector2Array([
			Vector2(x0, -w * 0.10 + wob),
			Vector2(x0 + span * 0.18, -w * 0.42),
			Vector2(x0 + span * 0.55, -w * 0.34),
			Vector2(L, 0.0),
			Vector2(x0 + span * 0.55, w * 0.34),
			Vector2(x0 + span * 0.18, w * 0.42),
			Vector2(x0, w * 0.10 + wob)])
		draw_colored_polygon(pts, col)

	# 枪尖爆点：出招瞬间亮一下，之后收掉。
	# 用三层递减排布做柔边，别画成实心圆（实心圆在加法混合下是一块灰饼）。
	if tip_flare > 0.0 and grow > 0.85:
		var ft: float = clampf((t - 0.04) / maxf(0.02, life * 0.45), 0.0, 1.0)
		var fr: float = width * (1.15 - ft * 0.75)
		var fa: float = (1.0 - ft) * 0.55 * fade * tip_flare
		for k in 3:
			var rr: float = fr * (1.0 - k * 0.32)
			draw_circle(Vector2(L, 0.0), rr,
				Color(CORE.r, CORE.g, CORE.b, fa * (0.22 + k * 0.16)))
		# 十字星芒：四道细尖，让「刺中」有个方向感
		var sl: float = fr * 2.1
		for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
			var d := Vector2(cos(ang), sin(ang))
			var perp := Vector2(-d.y, d.x) * fr * 0.10
			draw_colored_polygon(PackedVector2Array([
				Vector2(L, 0.0) + d * sl,
				Vector2(L, 0.0) + perp,
				Vector2(L, 0.0) - perp]),
				Color(1, 0.98, 0.92, fa * 0.75))

	# 速度线：只在尾段、贴着光带擦出去
	for ln in _lines:
		var y: float = ln[0] * width * 1.9
		var ln_len: float = span * float(ln[1])
		var lx: float = x0 + span * float(ln[2])
		var lc := color.lerp(CORE, 0.40)
		draw_line(Vector2(lx, y), Vector2(lx + ln_len, y * 0.55),
			Color(lc.r * 1.3, lc.g * 1.3, lc.b * 1.3, 0.40 * fade), 1.5)
