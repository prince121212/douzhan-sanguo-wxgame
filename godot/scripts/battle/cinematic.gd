extends CanvasLayer
## 演出层：黑边、绝技切入、开场标题、对阵牌、中央大字、拼刀角力条。全部真实时间。

var canvas: Control
var t := 0.0
var letterbox := 0.0
var letterbox_goal := 0.0

var cutin := {}          # 当前切入
var stamp := {}          # 中央大字
var title := {}          # 开场标题
var versus := {}         # 对阵牌
var clash := {}          # 角力条
var banner := {}         # 横幅提示（第二局等）
var speedlines := 0.0
var replay := {}         # 回放字样
var speed_dir := 1.0


var portrait_canvas: Control    # 绝技立绘，线性过滤（像素图已在贴图库里按整数倍放大）
var frame_canvas: Control       # 黑边，压在立绘上面（立绘冲出色带时由黑边收住）
var text_canvas: Control        # 绝技技名，压在立绘和黑边上面


func _ready() -> void:
	layer = 20
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_all)
	add_child(canvas)
	portrait_canvas = Control.new()
	portrait_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait_canvas.draw.connect(_draw_cutin_portrait)
	add_child(portrait_canvas)
	frame_canvas = Control.new()
	frame_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_canvas.draw.connect(_draw_letterbox)
	add_child(frame_canvas)
	text_canvas = Control.new()
	text_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_canvas.draw.connect(_draw_cutin_text)
	add_child(text_canvas)


func _process(delta: float) -> void:
	var dt: float = min(0.05, delta / max(0.0001, Engine.time_scale))
	t += dt
	letterbox = move_toward(letterbox, letterbox_goal, dt * 3.5)
	speedlines = move_toward(speedlines, 0.0, dt * 1.5)
	for d in [cutin, stamp, title, versus, banner]:
		if not d.is_empty():
			d["t"] += dt
			if d["t"] >= d["dur"]:
				d.clear()
	if not clash.is_empty():
		clash["t"] += dt
	if not replay.is_empty():
		replay["t"] += dt
	canvas.queue_redraw()
	portrait_canvas.queue_redraw()
	frame_canvas.queue_redraw()
	text_canvas.queue_redraw()


# ---------------------------------------------------------------- 接口

func set_letterbox(on: bool) -> void:
	letterbox_goal = 1.0 if on else 0.0


func show_cutin(f: Fighter, dur := 1.05) -> void:
	show_cutin_for(f.id, f.side, f.theme_color, dur)


func show_cutin_for(id: String, side: int, col: Color, dur := 1.05) -> void:
	var d := Roster.get_def(id)
	var tex: Texture2D = Bank.cutin(id)
	cutin = {"t": 0.0, "dur": dur, "side": side, "name": d["call"], "ult": d["ult"]["name"],
		"epithet": d["epithet"], "color": col, "tex": tex, "art": tex != null,
		"shout": Roster.line(id, "ult")}
	if tex == null:
		var fb := Bank.cutin_fallback(id)
		cutin["tex"] = fb.get("tex")
		cutin["face"] = fb.get("face", Vector2.ZERO)
		cutin["face_w"] = fb.get("face_w", 100.0)
		cutin["n"] = fb.get("n", 1)
		cutin["mounted"] = fb.get("mounted", false)
	speedlines = 1.0
	speed_dir = 1.0 if side == 0 else -1.0


func show_stamp(text: String, col: Color, dur := 1.1, size := 220, sub := "", y_ratio := 0.44) -> void:
	stamp = {"t": 0.0, "dur": dur, "text": text, "color": col, "size": size, "sub": sub, "y": y_ratio}


func show_title(text: String, sub: String, dur := 2.4) -> void:
	title = {"t": 0.0, "dur": dur, "text": text, "sub": sub}


func show_versus(a: Fighter, b: Fighter, dur := 2.6) -> void:
	versus = {"t": 0.0, "dur": dur, "a": a, "b": b}


func show_banner(text: String, sub: String, col: Color, dur := 1.8) -> void:
	banner = {"t": 0.0, "dur": dur, "text": text, "sub": sub, "color": col}


func start_clash(a: Fighter, b: Fighter, player_side: int) -> void:
	clash = {"t": 0.0, "a": a, "b": b, "balance": 0.0, "player": player_side}


func update_clash(balance: float) -> void:
	if not clash.is_empty():
		clash["balance"] = balance


func end_clash() -> void:
	clash.clear()


func show_replay(on: bool, winner: Fighter) -> void:
	if on:
		replay = {"t": 0.0, "name": winner.def["name"] if winner else "", "color": winner.theme_color if winner else Color.WHITE}
	else:
		replay.clear()


func busy() -> bool:
	return not cutin.is_empty()


# ---------------------------------------------------------------- 绘制

func _draw_all() -> void:
	var c := canvas
	var sz := c.size
	if not cutin.is_empty():
		_draw_cutin(c, sz)
	if not title.is_empty():
		_draw_title(c, sz)
	if not versus.is_empty():
		_draw_versus(c, sz)
	if not clash.is_empty():
		_draw_clash(c, sz)
	if not banner.is_empty():
		_draw_banner(c, sz)
	if not stamp.is_empty():
		_draw_stamp(c, sz)
	if not replay.is_empty():
		_draw_replay(c, sz)


func _draw_letterbox() -> void:
	if letterbox > 0.001:
		var c := frame_canvas
		var sz := c.size
		var hgt := 118.0 * _ease(letterbox)
		c.draw_rect(Rect2(0, 0, sz.x, hgt), Color(0, 0, 0, 1))
		c.draw_rect(Rect2(0, sz.y - hgt, sz.x, hgt), Color(0, 0, 0, 1))


func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - clamp(x, 0.0, 1.0), 3.0)


func _text_center(c: Control, font: Font, text: String, center: Vector2, size: int, col: Color, outline := 0, out_col := Color.BLACK, spacing := 0.0) -> void:
	if spacing == 0.0:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var p := Vector2(center.x - w * 0.5, center.y + size * 0.36)
		if outline > 0:
			c.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, out_col)
		c.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		return
	# 字距拉开
	var chars := text.length()
	var widths: Array = []
	var total := 0.0
	for i in chars:
		var cw := font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		widths.append(cw)
		total += cw
	total += spacing * (chars - 1)
	var x := center.x - total * 0.5
	for i in chars:
		var p2 := Vector2(x, center.y + size * 0.36)
		if outline > 0:
			c.draw_string_outline(font, p2, text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, out_col)
		c.draw_string(font, p2, text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += widths[i] + spacing


func _cutin_geom(sz: Vector2) -> Dictionary:
	var k: float = cutin["t"]
	var dur: float = cutin["dur"]
	var inn := _ease(k / 0.16)
	var out := _ease((k - (dur - 0.18)) / 0.18)
	var side: int = cutin["side"]
	var dir := 1.0 if side == 0 else -1.0
	var band_h := 520.0
	var cy := sz.y * 0.5
	var slide := (1.0 - inn) * sz.x * 1.2 * -dir + out * sz.x * 1.2 * dir
	var skew := 160.0
	var pts := PackedVector2Array([
		Vector2(-200 + slide, cy - band_h * 0.5 + skew * 0.3), Vector2(sz.x + 200 + slide, cy - band_h * 0.5 - skew * 0.3),
		Vector2(sz.x + 200 + slide, cy + band_h * 0.5 - skew * 0.3), Vector2(-200 + slide, cy + band_h * 0.5 + skew * 0.3)])
	return {"k": k, "vis": inn * (1.0 - out), "side": side, "dir": dir, "band_h": band_h, "cy": cy, "slide": slide, "pts": pts}


## 绝技切入·底：压暗、斜切色带、速度线、金边
func _draw_cutin(c: Control, sz: Vector2) -> void:
	var g := _cutin_geom(sz)
	var k: float = g["k"]
	var vis: float = g["vis"]
	var dir: float = g["dir"]
	var cy: float = g["cy"]
	var band_h: float = g["band_h"]
	var slide: float = g["slide"]
	var pts: PackedVector2Array = g["pts"]
	var col: Color = cutin["color"]
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.5 * vis))
	var dark := Color(col.r * 0.18, col.g * 0.14, col.b * 0.14, 0.94)
	c.draw_colored_polygon(pts, dark)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 52:
		var y := cy + rng.randf_range(-band_h * 0.5, band_h * 0.5)
		var spd := rng.randf_range(1800.0, 4200.0)
		var L := rng.randf_range(160.0, 520.0)
		var x := fposmod(rng.randf() * sz.x - k * spd * dir, sz.x + L) - L * 0.5
		var a := rng.randf_range(0.15, 0.55) * vis
		c.draw_line(Vector2(x + slide, y), Vector2(x + L * dir + slide, y), Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, a), rng.randf_range(2.0, 6.0))
	c.draw_polyline(PackedVector2Array([pts[0], pts[1]]), Color(1.0, 0.82, 0.35, vis), 6.0)
	c.draw_polyline(PackedVector2Array([pts[3], pts[2]]), Color(1.0, 0.82, 0.35, vis), 6.0)


## 绝技切入·立绘：贴进色带（多边形 UV 映射，自然被色带裁切），缓缓推近
func _draw_cutin_portrait() -> void:
	if cutin.is_empty():
		return
	var c := portrait_canvas
	var sz := c.size
	var tex: Texture2D = cutin["tex"]
	if tex == null:
		return
	var g := _cutin_geom(sz)
	var k: float = g["k"]
	var vis: float = g["vis"]
	var side: int = g["side"]
	var dir: float = g["dir"]
	var cy: float = g["cy"]
	var band_h: float = g["band_h"]
	var slide: float = g["slide"]
	var pts: PackedVector2Array = g["pts"]
	var art: bool = cutin["art"]
	var flip := side == 1
	var w := Color(1, 1, 1, vis)
	var drift := slide * 0.5 + k * 26.0 * dir
	var rect: Rect2
	if art:
		# 大招立绘：脸在画幅左侧约三分之一处，头顶高出色带上沿一截
		var art_h := band_h * 1.22 * (1.0 + k * 0.05)
		var art_w := art_h * float(tex.get_width()) / float(tex.get_height())
		var ax := -60.0 + drift
		if flip:
			ax = sz.x + 60.0 - art_w + drift
		var fx := ax + art_w * (0.35 if not flip else 0.65)
		rect = Rect2(ax, _band_top(pts, fx) - 60.0, art_w, art_h)
	else:
		# 像素立绘：脸放在左右四分之一处，头冲出色带上沿，兵器朝场中刺出
		var mounted: bool = cutin["mounted"]
		var face: Vector2 = cutin["face"]
		var s: float = minf(330.0 / float(cutin["face_w"]), 3.6 / float(cutin["n"])) * (1.0 + k * 0.03)
		var aw := float(tex.get_width()) * s
		var ah := float(tex.get_height()) * s
		var want := sz.x * (0.25 if side == 0 else 0.75) + drift
		var ax2 := want - face.x * s if not flip else want - (aw - face.x * s)
		rect = Rect2(ax2, cy - (60.0 if mounted else 20.0) - face.y * s, aw, ah)
	# 上沿让出一段给头顶和兵器，再往上渐隐，免得翎羽被一刀切平；下沿仍按色带裁齐
	var inset := PackedVector2Array([pts[0] + Vector2(0, 8), pts[1] + Vector2(0, 8), pts[2] - Vector2(0, 8), pts[3] - Vector2(0, 8)])
	var lift := Vector2(0, 130)
	var fade := Vector2(0, 70)
	var q_fade := PackedVector2Array([pts[0] - lift - fade, pts[1] - lift - fade, pts[1] - lift, pts[0] - lift])
	var q_body := PackedVector2Array([pts[0] - lift, pts[1] - lift, inset[2], inset[3]])
	var clear := Color(1, 1, 1, 0)
	if not art:
		# 像素立绘先垫一层主题色描边光
		var col: Color = cutin["color"]
		var glow := Color(col.r * 1.4, col.g * 1.4, col.b * 1.4, 0.45 * vis)
		var glow0 := Color(glow.r, glow.g, glow.b, 0.0)
		for o in [Vector2(-7, 0), Vector2(7, 0), Vector2(0, -7), Vector2(0, 7)]:
			_tex_quad(c, q_fade, rect, flip, tex, PackedColorArray([glow0, glow0, glow, glow]), o)
			_tex_quad(c, q_body, rect, flip, tex, PackedColorArray([glow, glow, glow, glow]), o)
	_tex_quad(c, q_fade, rect, flip, tex, PackedColorArray([clear, clear, w, w]))
	_tex_quad(c, q_body, rect, flip, tex, PackedColorArray([w, w, w, w]))


## 色带上沿在横坐标 x 处的高度
func _band_top(pts: PackedVector2Array, x: float) -> float:
	return lerpf(pts[0].y, pts[1].y, (x - pts[0].x) / (pts[1].x - pts[0].x))


## 在四边形 q 里贴图：贴图铺在 rect 上（flip 时左右镜像），off 让贴图相对四边形错开
func _tex_quad(c: CanvasItem, q: PackedVector2Array, rect: Rect2, flip: bool, tex: Texture2D, cols: PackedColorArray, off := Vector2.ZERO) -> void:
	var uvs := PackedVector2Array()
	for pt in q:
		var u := (pt - off - rect.position) / rect.size
		if flip:
			u.x = 1.0 - u.x
		uvs.append(u)
	c.draw_polygon(q, cols, uvs, tex)


## 绝技切入·字：技名墨迹、名号、喊招台词
func _draw_cutin_text() -> void:
	if cutin.is_empty():
		return
	var c := text_canvas
	var sz := c.size
	var g := _cutin_geom(sz)
	var k: float = g["k"]
	var vis: float = g["vis"]
	var side: int = g["side"]
	var dir: float = g["dir"]
	var cy: float = g["cy"]
	var band_h: float = g["band_h"]
	var slide: float = g["slide"]
	var tx := sz.x * 0.71 if side == 0 else sz.x * 0.29
	var font: Font = Game.font_brush
	var ult: String = cutin["ult"]
	var ty := cy - 20.0
	var pop: float = 1.0 + max(0.0, 0.25 - k) * 2.4
	c.draw_set_transform(Vector2(tx + slide * 0.3, ty), -0.06 * dir, Vector2(pop, pop))
	var brush := PackedVector2Array()
	for i in 24:
		var u := float(i) / 23.0
		brush.append(Vector2(lerp(-430.0, 430.0, u), -70.0 + sin(u * 31.0) * 9.0))
	for i in 24:
		var u := 1.0 - float(i) / 23.0
		brush.append(Vector2(lerp(-430.0, 430.0, u), 80.0 + cos(u * 27.0) * 11.0))
	c.draw_colored_polygon(brush, Color(0.55, 0.05, 0.04, 0.85 * vis))
	_text_center(c, font, ult, Vector2.ZERO, 132, Color(1.0, 0.88, 0.42, vis), 16, Color(0.12, 0.02, 0.01, vis), 18.0)
	_text_center(c, Game.font_title, cutin["name"] + " · " + cutin["epithet"], Vector2(0, 128), 40, Color(1, 1, 1, vis), 8, Color(0, 0, 0, vis), 6.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var shout: String = cutin.get("shout", "")
	if shout != "":
		var n := int(clamp((k - 0.12) * 40.0, 0.0, float(shout.length())))
		var shown := ("「" + shout.substr(0, n) + ("」" if n >= shout.length() else "")) if n > 0 else ""
		var sy := cy + band_h * 0.5 + 40.0
		_text_center(c, Game.font_title, shown, Vector2(sz.x * 0.5, sy), 46, Color(1.0, 0.95, 0.85, vis), 10, Color(0.05, 0.02, 0.01, vis), 2.0)


func _draw_title(c: Control, sz: Vector2) -> void:
	var k: float = title["t"]
	var dur: float = title["dur"]
	var a := _ease(k / 0.4) * (1.0 - _ease((k - dur + 0.5) / 0.5))
	var font: Font = Game.font_brush
	var center := Vector2(sz.x * 0.5, sz.y * 0.42)
	var sc := 1.0 + (1.0 - _ease(k / 0.5)) * 0.4
	c.draw_set_transform(center, 0.0, Vector2(sc, sc))
	var brush := PackedVector2Array()
	for i in 30:
		var u := float(i) / 29.0
		brush.append(Vector2(lerp(-520.0, 520.0, u) * _ease(k / 0.5), -90.0 + sin(u * 40.0) * 12.0))
	for i in 30:
		var u := 1.0 - float(i) / 29.0
		brush.append(Vector2(lerp(-520.0, 520.0, u) * _ease(k / 0.5), 100.0 + cos(u * 33.0) * 14.0))
	c.draw_colored_polygon(brush, Color(0.08, 0.05, 0.04, 0.78 * a))
	_text_center(c, font, title["text"], Vector2(0, -6), 168, Color(0.98, 0.9, 0.7, a), 14, Color(0.25, 0.04, 0.02, a), 36.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_text_center(c, Game.font_title, title["sub"], center + Vector2(0, 150), 44, Color(1, 0.85, 0.55, a), 8, Color(0, 0, 0, a), 10.0)


func _draw_versus(c: Control, sz: Vector2) -> void:
	var k: float = versus["t"]
	var dur: float = versus["dur"]
	var inn := _ease(k / 0.3)
	var out := _ease((k - dur + 0.35) / 0.35)
	var a: Fighter = versus["a"]
	var b: Fighter = versus["b"]
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	var font: Font = Game.font_title
	var y := sz.y * 0.72
	for i in 2:
		var f: Fighter = a if i == 0 else b
		var dir := -1.0 if i == 0 else 1.0
		var off := (1.0 - inn) * 900.0 * dir + out * 900.0 * dir
		var cx := sz.x * (0.27 if i == 0 else 0.73) + off
		var col: Color = f.theme_color
		var plate := PackedVector2Array([Vector2(cx - 400, y - 70), Vector2(cx + 400, y - 90), Vector2(cx + 380, y + 70), Vector2(cx - 420, y + 90)])
		c.draw_colored_polygon(plate, Color(col.r * 0.2, col.g * 0.15, col.b * 0.15, 0.92))
		c.draw_polyline(plate + PackedVector2Array([plate[0]]), Color(1, 0.8, 0.35, 0.95), 4.0)
		var portrait: Texture2D = Bank.portrait(f.id)
		if portrait:
			var ph := 200.0
			var pw: float = ph * portrait.get_width() / max(1.0, float(portrait.get_height()))
			var px := cx - 360.0 if i == 0 else cx + 360.0 - pw
			var rect := Rect2(px, y - ph + 60, pw, ph)
			if i == 1:
				c.draw_set_transform(Vector2((px + pw * 0.5) * 2.0, 0), 0.0, Vector2(-1, 1))
			c.draw_texture_rect(portrait, rect, false)
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var name_x := cx + 60.0 if i == 0 else cx - 60.0
		_text_center(c, font, f.def["home"] + " " + f.def["name"] + f.def["zi"], Vector2(name_x, y - 10), 68, Color(1.0, 0.92, 0.75), 10, Color(0.1, 0.02, 0.01), 4.0)
		_text_center(c, Game.font_ui, f.def["epithet"] + " · " + f.def["weapon_name"], Vector2(name_x, y + 52), 28, Color(col.r, col.g, col.b).lerp(Color.WHITE, 0.4), 6, Color(0, 0, 0))
	# 中间的"斗"字印
	var seal_a := _ease((k - 0.25) / 0.2) * (1.0 - out)
	var seal_s := 1.0 + maxf(0.0, 0.45 - k) * 3.0
	c.draw_set_transform(Vector2(sz.x * 0.5, y), 0.08, Vector2(seal_s, seal_s))
	c.draw_circle(Vector2.ZERO, 92.0, Color(0.62, 0.06, 0.04, 0.95 * seal_a))
	c.draw_arc(Vector2.ZERO, 92.0, 0.0, TAU, 48, Color(1, 0.8, 0.4, seal_a), 6.0)
	_text_center(c, Game.font_brush, "斗", Vector2(0, -6), 120, Color(1.0, 0.9, 0.7, seal_a), 10, Color(0.2, 0.02, 0.01, seal_a))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_stamp(c: Control, sz: Vector2) -> void:
	var k: float = stamp["t"]
	var dur: float = stamp["dur"]
	var a := 1.0 - _ease((k - dur + 0.3) / 0.3)
	var s := lerpf(2.6, 1.0, _ease(k / 0.14))
	var font: Font = Game.font_brush
	var center := Vector2(sz.x * 0.5, sz.y * float(stamp.get("y", 0.44)))
	var col: Color = stamp["color"]
	c.draw_set_transform(center, -0.05, Vector2(s, s))
	# 墨点
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(stamp["text"])
	for i in 9:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(110.0, 190.0)
		c.draw_circle(Vector2(cos(ang), sin(ang)) * r * 0.6, rng.randf_range(30.0, 70.0), Color(0.06, 0.03, 0.02, 0.5 * a))
	c.draw_circle(Vector2.ZERO, 150.0, Color(0.06, 0.03, 0.02, 0.6 * a))
	_text_center(c, font, stamp["text"], Vector2(0, -10), stamp["size"], Color(col.r, col.g, col.b, a), 18, Color(0.1, 0.01, 0.0, a))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if stamp["sub"] != "":
		_text_center(c, font, stamp["sub"], center + Vector2(0, 190), 54, Color(1, 0.92, 0.75, a), 10, Color(0, 0, 0, a), 8.0)


func _draw_replay(c: Control, sz: Vector2) -> void:
	var k: float = replay["t"]
	var a := _ease(k / 0.3)
	# 胶片感：四角取景框 + 竖条噪点
	var m := 140.0
	var L := 70.0
	var col := Color(1, 0.95, 0.85, 0.75 * a)
	for corner in [Vector2(m, m), Vector2(sz.x - m, m), Vector2(m, sz.y - m), Vector2(sz.x - m, sz.y - m)]:
		var dx := 1.0 if corner.x < sz.x * 0.5 else -1.0
		var dy := 1.0 if corner.y < sz.y * 0.5 else -1.0
		c.draw_line(corner, corner + Vector2(L * dx, 0), col, 4.0)
		c.draw_line(corner, corner + Vector2(0, L * dy), col, 4.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(k * 24.0)
	for i in 3:
		var x := rng.randf_range(0.0, sz.x)
		c.draw_line(Vector2(x, 118), Vector2(x + rng.randf_range(-4, 4), sz.y - 118), Color(1, 1, 1, 0.06 * a), 2.0)
	# 左上：回放字样，红点闪烁
	var blink := 0.5 + 0.5 * sin(k * 7.0)
	c.draw_circle(Vector2(m + 30, m + 48), 12.0, Color(0.9, 0.12, 0.08, a * (0.4 + 0.6 * blink)))
	c.draw_string_outline(Game.font_brush, Vector2(m + 56, m + 66), "精彩回放", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, 10, Color(0.05, 0.02, 0.01, a))
	c.draw_string(Game.font_brush, Vector2(m + 56, m + 66), "精彩回放", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color(1, 0.92, 0.75, a))
	var sub: String = "%s 致胜一击" % replay["name"]
	c.draw_string(Game.font_title, Vector2(m + 58, m + 106), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.85, 0.55, a * 0.9))


func _draw_banner(c: Control, sz: Vector2) -> void:
	var k: float = banner["t"]
	var dur: float = banner["dur"]
	var a := _ease(k / 0.25) * (1.0 - _ease((k - dur + 0.35) / 0.35))
	var y := sz.y * 0.36
	var w := sz.x * _ease(k / 0.3)
	var col: Color = banner["color"]
	c.draw_rect(Rect2(sz.x * 0.5 - w * 0.5, y - 70, w, 140), Color(0.05, 0.03, 0.02, 0.78 * a))
	c.draw_rect(Rect2(sz.x * 0.5 - w * 0.5, y - 74, w, 4), Color(col.r, col.g, col.b, a))
	c.draw_rect(Rect2(sz.x * 0.5 - w * 0.5, y + 70, w, 4), Color(col.r, col.g, col.b, a))
	_text_center(c, Game.font_brush, banner["text"], Vector2(sz.x * 0.5, y - 12), 84, Color(1, 0.92, 0.72, a), 10, Color(0.15, 0.02, 0.01, a), 20.0)
	if banner["sub"] != "":
		_text_center(c, Game.font_ui, banner["sub"], Vector2(sz.x * 0.5, y + 48), 28, Color(1, 1, 1, a * 0.85))


func _draw_clash(c: Control, sz: Vector2) -> void:
	var a: Fighter = clash["a"]
	var b: Fighter = clash["b"]
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	var k: float = clash["t"]
	var vis := _ease(k / 0.2)
	var bal: float = clash["balance"]  # -1 左方占优 … +1 右方占优，分界线向劣势一方移动
	var w := 760.0
	var cx := sz.x * 0.5
	var y := sz.y - 205.0
	var left_col: Color = a.theme_color if a.side == 0 else b.theme_color
	var right_col: Color = b.theme_color if a.side == 0 else a.theme_color
	var split := cx - bal * w * 0.5
	c.draw_rect(Rect2(cx - w * 0.5 - 6, y - 6, w + 12, 40), Color(0.05, 0.02, 0.01, 0.85 * vis))
	c.draw_rect(Rect2(cx - w * 0.5, y, split - (cx - w * 0.5), 28), Color(left_col.r, left_col.g, left_col.b, vis))
	c.draw_rect(Rect2(split, y, cx + w * 0.5 - split, 28), Color(right_col.r, right_col.g, right_col.b, vis))
	c.draw_rect(Rect2(split - 5, y - 10, 10, 48), Color(1, 1, 1, vis))
	_text_center(c, Game.font_brush, "拼刀 · 角力", Vector2(cx, y - 48), 60, Color(1, 0.88, 0.5, vis), 10, Color(0.1, 0.02, 0.0, vis), 8.0)
	if clash["player"] >= 0:
		var blink := 0.5 + 0.5 * sin(k * 18.0)
		_text_center(c, Game.font_ui, "连按 J / K 角力！", Vector2(cx, y + 64), 30, Color(1, 1, 1, vis * (0.6 + 0.4 * blink)), 6, Color(0, 0, 0, vis))
