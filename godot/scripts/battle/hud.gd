extends CanvasLayer
## 战斗 HUD：两侧武将栏（头像、名号、体力、怒气、气力）、计时、合数、战报、连击。

var battle: Node
var canvas: Control
var t := 0.0
var shown := 0.0
var shown_goal := 0.0

var lag_hp := [1.0, 1.0]       # 体力条滞后显示（白色掉血痕）
var shake := [0.0, 0.0]
var last_hp := [1.0, 1.0]
var rage_flash := [0.0, 0.0]
var combo_show := [0, 0]
var combo_t := [0.0, 0.0]
var ticker: Array = []         # 战报 {text, t, imp}
var round_pop := 0.0
var last_round := 0


func _ready() -> void:
	layer = 10
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_hud)
	add_child(canvas)


func narrate(text: String, imp := 0) -> void:
	ticker.push_front({"text": text, "t": 0.0, "imp": imp})
	while ticker.size() > 3:
		ticker.pop_back()


func show_combo(side: int, n: int) -> void:
	combo_show[side] = n
	combo_t[side] = 1.4


var user_hidden := false


func set_visible_hud(on: bool) -> void:
	user_hidden = not on


func _process(delta: float) -> void:
	var dt: float = min(0.05, delta / max(0.0001, Engine.time_scale))
	t += dt
	if battle == null:
		return
	# 演出黑边出现时，血条收起；用户按 Tab 隐藏时也收起
	var lb: float = battle.cine.letterbox_goal if battle.cine else 0.0
	shown_goal = 0.0 if (user_hidden or lb > 0.5 or battle.phase == "intro") else 1.0
	shown = move_toward(shown, shown_goal, dt * 4.0)
	var fs: Array = battle.fighters
	for i in min(2, fs.size()):
		var f: Fighter = fs[i]
		var r := f.hp / f.max_hp
		if r < last_hp[i] - 0.001:
			shake[i] = 1.0
		last_hp[i] = r
		if lag_hp[i] > r:
			lag_hp[i] = move_toward(lag_hp[i], r, dt * (0.12 if battle.game_time - f.last_hit_time < 0.7 else 0.6))
		else:
			lag_hp[i] = r
		shake[i] = move_toward(shake[i], 0.0, dt * 4.0)
		combo_t[i] = max(0.0, combo_t[i] - dt)
		rage_flash[i] = move_toward(rage_flash[i], 0.0, dt * 2.0)
	for m in ticker:
		m["t"] += dt
	while ticker.size() > 0 and ticker[ticker.size() - 1]["t"] > 5.5:
		ticker.pop_back()
	if battle.round_count != last_round:
		last_round = battle.round_count
		round_pop = 1.0
	round_pop = move_toward(round_pop, 0.0, dt * 2.5)
	canvas.queue_redraw()


func _draw_hud() -> void:
	if battle == null:
		return
	if shown <= 0.01:
		if not user_hidden:
			_draw_ticker(canvas, canvas.size)
		return
	var c := canvas
	var sz := c.size
	var fs: Array = battle.fighters
	if fs.size() < 2:
		return
	var drop := (1.0 - shown) * -220.0
	for i in 2:
		_draw_panel(c, sz, fs[i], i, drop)
	_draw_center(c, sz, drop)
	_draw_ticker(c, sz)
	if battle.player_side >= 0:
		_draw_player_hints(c, sz, fs[battle.player_side])


## 玩家提示：开场按键说明、怒气满时的绝技提示
func _draw_player_hints(c: Control, sz: Vector2, f: Fighter) -> void:
	var ui: Font = Game.font_ui
	var since: float = battle.game_time - battle.match_start_time
	# 触屏版按钮本身就写着「轻 连招 / 重 按住蓄力 / 挡 拆招 / 闪 闪避」，
	# 再在屏幕底部铺一条键盘键位说明只会挡住摇杆和按钮，所以触屏下不画。
	if battle.phase == "fight" and since < 14.0 and not Game.touch_ui:
		var a: float = clamp((14.0 - since) / 1.5, 0.0, 1.0) * clamp(since / 0.5, 0.0, 1.0)
		var keys := [["WASD", "移动"], ["J", "轻击"], ["K", "重击·按住蓄力"], ["L", "格挡·看准时机拆招"], ["空格", "闪避·马上按住冲锋"], ["Shift", "疾跑"], ["I", "跳"], ["U", "绝技"], ["Esc", "暂停"]]
		var x := 0.0
		var widths: Array = []
		for k in keys:
			var w: float = ui.get_string_size(k[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 22.0 + ui.get_string_size(k[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 34.0
			widths.append(w)
			x += w
		var x0 := (sz.x - x) * 0.5
		var y := sz.y - 150.0
		c.draw_rect(Rect2(x0 - 20.0, y - 30.0, x + 40.0, 50.0), Color(0.04, 0.02, 0.01, 0.62 * a))
		for i in keys.size():
			var k: Array = keys[i]
			var kw: float = ui.get_string_size(k[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 16.0
			c.draw_rect(Rect2(x0, y - 22.0, kw, 32.0), Color(0.85, 0.65, 0.3, 0.9 * a))
			c.draw_string(ui, Vector2(x0 + 8.0, y + 2.0), k[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.1, 0.04, 0.02, a))
			c.draw_string(ui, Vector2(x0 + kw + 8.0, y + 2.0), k[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.94, 0.82, a))
			x0 += widths[i]
	if f.rage >= 100.0 and battle.phase == "fight":
		var blink := 0.55 + 0.45 * sin(t * 7.0)
		var txt := ("点「绝」发动绝技「%s」" if Game.touch_ui else "按 U 发动绝技「%s」") % f.def["ult"]["name"]
		var font: Font = Game.font_title
		var w2 := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var px := 200.0 if f.side == 0 else sz.x - 200.0 - w2
		var py := 210.0
		c.draw_string_outline(font, Vector2(px, py), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 7, Color(0.1, 0.02, 0.0, blink))
		c.draw_string(font, Vector2(px, py), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.86, 0.4, blink))


func _bar(c: Control, rect: Rect2, ratio: float, col_a: Color, col_b: Color, flip: bool) -> void:
	ratio = clamp(ratio, 0.0, 1.0)
	var w := rect.size.x * ratio
	var r := Rect2(rect.position.x + (rect.size.x - w if flip else 0.0), rect.position.y, w, rect.size.y)
	if w <= 0.5:
		return
	# 竖向渐变：上亮下暗
	var steps := 6
	for s in steps:
		var u := float(s) / steps
		var col := col_a.lerp(col_b, u)
		c.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * u, r.size.x, r.size.y / steps + 1), col)
	c.draw_rect(Rect2(r.position.x, r.position.y + 2, r.size.x, 3), Color(1, 1, 1, 0.35))


func _slant(c: Control, rect: Rect2, skew: float, col: Color, flip: bool) -> void:
	var s := -skew if flip else skew
	var pts := PackedVector2Array([
		rect.position + Vector2(max(0.0, s), 0), rect.position + Vector2(rect.size.x + min(0.0, s), 0),
		rect.position + Vector2(rect.size.x - max(0.0, s), rect.size.y), rect.position + Vector2(-min(0.0, s), rect.size.y)])
	c.draw_colored_polygon(pts, col)


func _draw_panel(c: Control, sz: Vector2, f: Fighter, i: int, drop: float) -> void:
	var flip := i == 1
	var font: Font = Game.font_title
	var ui: Font = Game.font_ui
	var sx: float = sin(t * 70.0) * 6.0 * shake[i]
	var y0 := 26.0 + drop
	var col: Color = f.theme_color
	var bar_w := 640.0
	var portrait_c := Vector2(108.0 if not flip else sz.x - 108.0, y0 + 76.0) + Vector2(sx, 0)
	var bar_x := 196.0 if not flip else sz.x - 196.0 - bar_w
	bar_x += sx
	# 底板
	var plate := Rect2(bar_x - 24.0, y0 + 2.0, bar_w + 48.0, 128.0)
	_slant(c, plate, 26.0, Color(0.05, 0.03, 0.02, 0.62), flip)
	# 名号
	var name_text: String = f.def["name"]
	var zi: String = f.def["zi"]
	var name_pos := Vector2(bar_x + 4.0, y0 + 40.0) if not flip else Vector2(bar_x + bar_w - 4.0, y0 + 40.0)
	var nw := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
	var zw := ui.get_string_size(zi, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	if flip:
		name_pos.x -= nw
	c.draw_string_outline(font, name_pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, 8, Color(0.08, 0.02, 0.01))
	c.draw_string(font, name_pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(1.0, 0.93, 0.78))
	var zi_pos := name_pos + Vector2(nw + 10.0, -2.0) if not flip else name_pos + Vector2(-zw - 10.0, -2.0)
	c.draw_string(ui, zi_pos, zi, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(col.r, col.g, col.b).lerp(Color.WHITE, 0.4))
	# 胜局标记
	if battle.rounds_to_win > 1:
		for w in battle.rounds_to_win:
			var won: bool = battle.wins[i] > w
			var mx: float = bar_x + bar_w - 20.0 - w * 30.0 if not flip else bar_x + 20.0 + w * 30.0
			c.draw_circle(Vector2(mx, y0 + 26.0), 10.0, Color(0.1, 0.05, 0.03))
			c.draw_circle(Vector2(mx, y0 + 26.0), 7.0, Color(1.0, 0.75, 0.2) if won else Color(0.3, 0.25, 0.2))
	# 状态（骑/步）
	var tag := "骑" if f.mounted else "步"
	var tag_x := bar_x + bar_w - 70.0 if not flip else bar_x + 70.0
	if battle.rounds_to_win > 1:
		tag_x += -90.0 if not flip else 90.0
	c.draw_circle(Vector2(tag_x, y0 + 24.0), 17.0, Color(0.55, 0.08, 0.05, 0.9))
	var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	c.draw_string(font, Vector2(tag_x - tw * 0.5, y0 + 33.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.9, 0.7))
	# 体力条
	var hp_rect := Rect2(bar_x, y0 + 56.0, bar_w, 34.0)
	c.draw_rect(hp_rect.grow(4.0), Color(0.08, 0.03, 0.02))
	c.draw_rect(hp_rect, Color(0.18, 0.08, 0.06))
	var ratio := f.hp / f.max_hp
	_bar(c, hp_rect, lag_hp[i], Color(1.0, 0.95, 0.85), Color(0.85, 0.7, 0.55), flip)
	var low := ratio < 0.25
	var ca := Color(1.0, 0.36, 0.2) if not flip else Color(0.95, 0.3, 0.32)
	var cb := Color(0.62, 0.08, 0.05) if not flip else Color(0.5, 0.06, 0.12)
	if low:
		var p := 0.5 + 0.5 * sin(t * 10.0)
		ca = ca.lerp(Color(1, 0.9, 0.5), p * 0.5)
	_bar(c, hp_rect, ratio, ca, cb, flip)
	# 落马线（55%）
	if f.mounted and f.can_unhorse and not f.unhorsed:
		var lx := hp_rect.position.x + hp_rect.size.x * (0.55 if not flip else 0.45)
		c.draw_line(Vector2(lx, hp_rect.position.y - 4), Vector2(lx, hp_rect.end.y + 4), Color(1, 0.85, 0.4, 0.9), 3.0)
	for k in range(1, 10):
		var tx := hp_rect.position.x + hp_rect.size.x * k / 10.0
		c.draw_line(Vector2(tx, hp_rect.position.y), Vector2(tx, hp_rect.position.y + 8), Color(0, 0, 0, 0.35), 2.0)
	c.draw_rect(hp_rect.grow(4.0), Color(0.85, 0.65, 0.3), false, 3.0)
	var hp_txt := "%d" % int(ceil(f.hp))
	var hw := ui.get_string_size(hp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var hx := hp_rect.position.x + 10.0 if flip else hp_rect.end.x - hw - 10.0
	c.draw_string_outline(ui, Vector2(hx, hp_rect.position.y + 25.0), hp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.8))
	c.draw_string(ui, Vector2(hx, hp_rect.position.y + 25.0), hp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.9))
	# 怒气条
	var rg_w := 470.0
	var rg_rect := Rect2(bar_x if not flip else bar_x + bar_w - rg_w, y0 + 100.0, rg_w, 16.0)
	c.draw_rect(rg_rect.grow(3.0), Color(0.06, 0.03, 0.02))
	var full := f.rage >= 100.0
	var rc_a := Color(1.0, 0.85, 0.35) if full else Color(0.95, 0.62, 0.2)
	var rc_b := Color(1.0, 0.5, 0.1) if full else Color(0.6, 0.3, 0.08)
	if full:
		var p2 := 0.5 + 0.5 * sin(t * 8.0)
		rc_a = rc_a.lerp(Color(1, 1, 0.9), p2 * 0.6)
	_bar(c, rg_rect, f.rage / 100.0, rc_a, rc_b, flip)
	for k in range(1, 4):
		var tx2 := rg_rect.position.x + rg_rect.size.x * k / 4.0
		c.draw_line(Vector2(tx2, rg_rect.position.y), Vector2(tx2, rg_rect.end.y), Color(0, 0, 0, 0.5), 2.0)
	c.draw_rect(rg_rect.grow(3.0), Color(0.7, 0.5, 0.25), false, 2.0)
	# "绝"字徽
	var seal := Vector2(rg_rect.end.x + 30.0, rg_rect.get_center().y) if not flip else Vector2(rg_rect.position.x - 30.0, rg_rect.get_center().y)
	var sa := 1.0 if full else 0.35
	var sr := 22.0 + (sin(t * 8.0) * 3.0 if full else 0.0)
	c.draw_circle(seal, sr, Color(0.6 * sa + 0.1, 0.08, 0.04, 0.95))
	c.draw_arc(seal, sr, 0.0, TAU, 32, Color(1.0, 0.8, 0.35, sa), 3.0)
	var jw := font.get_string_size("绝", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	c.draw_string(font, seal + Vector2(-jw * 0.5, 10.0), "绝", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.92, 0.7, sa))
	# 气力条
	var st_w := 300.0
	var st_rect := Rect2(bar_x if not flip else bar_x + bar_w - st_w, y0 + 122.0, st_w, 6.0)
	c.draw_rect(st_rect.grow(2.0), Color(0.05, 0.03, 0.02, 0.8))
	_bar(c, st_rect, f.stamina / Fighter.STAMINA_MAX, Color(0.7, 0.95, 0.7), Color(0.35, 0.6, 0.35), flip)
	# 头像
	var pr := 64.0
	c.draw_circle(portrait_c, pr + 6.0, Color(0.85, 0.65, 0.3))
	c.draw_circle(portrait_c, pr, Color(col.r * 0.35, col.g * 0.3, col.b * 0.3))
	var por: Texture2D = Bank.portrait(f.id)
	if por:
		var ph := pr * 2.2
		var pw: float = ph * por.get_width() / max(1.0, float(por.get_height()))
		var rect := Rect2(portrait_c.x - pw * 0.5, portrait_c.y - ph * 0.62, pw, ph)
		var tint := Color.WHITE
		if f.hp <= 0.0:
			tint = Color(0.4, 0.4, 0.4)
		if flip:
			c.draw_set_transform(Vector2(portrait_c.x * 2.0, 0), 0.0, Vector2(-1, 1))
		c.draw_texture_rect(por, rect, false, tint)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_arc(portrait_c, pr + 3.0, 0.0, TAU, 48, Color(0.25, 0.08, 0.03), 4.0)
	var fac: String = f.def["faction"]
	var fcol: Color = {"蜀": Color(0.15, 0.55, 0.25), "魏": Color(0.2, 0.35, 0.75), "吴": Color(0.8, 0.25, 0.2), "群": Color(0.55, 0.15, 0.55)}.get(fac, Color(0.4, 0.4, 0.4))
	var fp := portrait_c + Vector2(pr * 0.72 * (1.0 if not flip else -1.0), pr * 0.72)
	c.draw_circle(fp, 20.0, fcol)
	c.draw_arc(fp, 20.0, 0.0, TAU, 24, Color(1, 0.85, 0.4), 2.5)
	var fw := font.get_string_size(fac, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	c.draw_string(font, fp + Vector2(-fw * 0.5, 9.0), fac, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1))
	# 连击
	if combo_t[i] > 0.0 and combo_show[i] >= 2:
		var ca2: float = min(1.0, combo_t[i] / 0.4)
		var pop: float = 1.0 + max(0.0, combo_t[i] - 1.2) * 2.0
		var cx := 120.0 if not flip else sz.x - 120.0
		var cy := 300.0 + drop
		# 触屏版右上角有暂停按钮（头像下方），敌方连击数字往下让一让，免得压在一起
		if flip and Game.touch_ui:
			cy += 130.0
		c.draw_set_transform(Vector2(cx, cy), -0.08 if not flip else 0.08, Vector2(pop, pop))
		var num := str(combo_show[i])
		var nwid := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 92).x
		c.draw_string_outline(font, Vector2(-nwid * 0.5, 0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 92, 12, Color(0.12, 0.02, 0.0, ca2))
		c.draw_string(font, Vector2(-nwid * 0.5, 0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 92, Color(1.0, 0.85, 0.35, ca2))
		var lw := font.get_string_size("连击", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		c.draw_string_outline(font, Vector2(-lw * 0.5, 46), "连击", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 8, Color(0.12, 0.02, 0.0, ca2))
		c.draw_string(font, Vector2(-lw * 0.5, 46), "连击", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 0.95, 0.85, ca2))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_center(c: Control, sz: Vector2, drop: float) -> void:
	var font: Font = Game.font_title
	var cx := sz.x * 0.5
	var cy := 82.0 + drop
	# 计时牌
	c.draw_circle(Vector2(cx, cy), 62.0, Color(0.85, 0.65, 0.3))
	c.draw_circle(Vector2(cx, cy), 56.0, Color(0.12, 0.05, 0.03))
	c.draw_arc(Vector2(cx, cy), 48.0, 0.0, TAU, 40, Color(0.5, 0.2, 0.08), 2.0)
	var secs := int(ceil(max(0.0, battle.time_left)))
	var ts := str(secs)
	var tcol := Color(1.0, 0.9, 0.7)
	if secs <= 15:
		tcol = Color(1.0, 0.35, 0.25).lerp(Color(1, 0.9, 0.7), 0.5 + 0.5 * sin(t * 8.0))
	var tw := font.get_string_size(ts, HORIZONTAL_ALIGNMENT_LEFT, -1, 62).x
	c.draw_string(font, Vector2(cx - tw * 0.5, cy + 22.0), ts, HORIZONTAL_ALIGNMENT_LEFT, -1, 62, tcol)
	# 合数
	var rtext: String = "第 %d 合" % maxi(1, battle.round_count)
	var rs := 34 + int(round_pop * 10.0)
	var rw := font.get_string_size(rtext, HORIZONTAL_ALIGNMENT_LEFT, -1, rs).x
	c.draw_string_outline(font, Vector2(cx - rw * 0.5, cy + 106.0), rtext, HORIZONTAL_ALIGNMENT_LEFT, -1, rs, 8, Color(0.08, 0.02, 0.01))
	c.draw_string(font, Vector2(cx - rw * 0.5, cy + 106.0), rtext, HORIZONTAL_ALIGNMENT_LEFT, -1, rs, Color(1.0, 0.85, 0.5).lerp(Color.WHITE, round_pop))
	# 模式标签
	var label: String = battle.mode_label()
	if label != "":
		var lw := Game.font_ui.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		c.draw_rect(Rect2(cx - lw * 0.5 - 14, cy + 124.0, lw + 28, 34), Color(0.05, 0.02, 0.01, 0.55))
		c.draw_string(Game.font_ui, Vector2(cx - lw * 0.5, cy + 148.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.9, 0.75, 0.9))


func _draw_ticker(c: Control, sz: Vector2) -> void:
	var font: Font = Game.font_title
	var lb: float = battle.cine.letterbox if battle.cine else 0.0
	# 触屏下右下角是招式按钮，战报要抬高一点免得被压住
	var base_y := sz.y - 58.0 - 110.0 * lb - (96.0 if Game.touch_ui else 0.0)
	for idx in ticker.size():
		var m: Dictionary = ticker[idx]
		var a: float = clamp(m["t"] / 0.25, 0.0, 1.0) * (1.0 - clamp((m["t"] - 4.5) / 1.0, 0.0, 1.0))
		a *= [1.0, 0.55, 0.3][idx]
		var size := 38 if idx == 0 else 30
		if m["imp"] > 0 and idx == 0:
			size = 44
		var text: String = m["text"]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var y := base_y - idx * 46.0
		var slide: float = (1.0 - clamp(m["t"] / 0.25, 0.0, 1.0)) * 30.0
		if idx == 0:
			c.draw_rect(Rect2(sz.x * 0.5 - w * 0.5 - 40, y - size - 6, w + 80, size + 22), Color(0.04, 0.02, 0.01, 0.55 * a))
			c.draw_rect(Rect2(sz.x * 0.5 - w * 0.5 - 40, y - size - 6, 6, size + 22), Color(0.8, 0.2, 0.1, a))
		var col := Color(1, 0.92, 0.75, a) if m["imp"] == 0 else Color(1.0, 0.8, 0.35, a)
		c.draw_string_outline(font, Vector2(sz.x * 0.5 - w * 0.5, y + slide), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 7, Color(0, 0, 0, a))
		c.draw_string(font, Vector2(sz.x * 0.5 - w * 0.5, y + slide), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
